/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

using namespace std;

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

int comment_depth;
int string_started = 0;
string string_collect = "";

extern YYSTYPE cool_yylval;
/*
 *  Add Your own definitions here
 */

%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
LE              <=
DIGIT           [0-9]
INTEGER         [0-9.]+
TRUE            t(?i:rue)
FALSE           f(?i:alse)
TYPE_ID         [A-Z][A-Za-z0-9_]*
OBJECT_ID       [a-z][A-Za-z0-9_]*
COMMENT_START   \(\*
COMMENT_END     \*\)
SINGLE_COMMENT_START  --
SPACE           [ \t\f\015\013]+

INHERITS        (?i:inherits)
CLASS           (?i:class)
IF		          (?i:if)
FI              (?i:fi)
THEN            (?i:then)
ELSE            (?i:else)
IN              (?i:in)
ISVOID          (?i:isvoid)
CASE            (?i:case)
ESAC            (?i:esac)
LET             (?i:let)
LOOP            (?i:loop)
NEW             (?i:new)
NOT             (?i:not)
OF              (?i:of)
POOL            (?i:pool)
WHILE           (?i:while)

SINGLE_CHAR     [\(\)\;\:\.\{\}\+\-=,@\*\/~<]

%x SINGLE_COMMENT
%x COMMENT_NESTED
%x STRING
%%

 /*
  *  Nested comments
  */


 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }
{LE}        { return (LE); }
{INHERITS}  { return (INHERITS); }
{CLASS}     { return (CLASS); }
{IF}        { return (IF); }
{FI}        { return (FI); }
{THEN}      { return (THEN); }
{ELSE}      { return (ELSE); }
{IN}        { return (IN); }
{ISVOID}      { return (ISVOID); }
{CASE}        { return (CASE); }
{ESAC}        { return (ESAC); }
{LET}         { return (LET); }
{LOOP}        { return (LOOP); }
{NEW}         { return (NEW); }
{NOT}         { return (NOT); }
{OF}          { return (OF); }
{POOL}        { return (POOL); }
{WHILE}       { return (WHILE); }

{SPACE} {}


{SINGLE_CHAR} { 
  return int(yytext[0]);
}

{TRUE} {
  cool_yylval.boolean = true;

  return BOOL_CONST;
}

{FALSE} {
  cool_yylval.boolean = false;

  return BOOL_CONST;
}

{TYPE_ID} {
  cool_yylval.symbol = idtable.add_string(yytext);
  return TYPEID;
}
{OBJECT_ID} { 
  cool_yylval.symbol = idtable.add_string(yytext);
  return OBJECTID; 
}
{INTEGER} { 
  cool_yylval.symbol = inttable.add_string(yytext);
  return INT_CONST;
}

\<- {
  return ASSIGN;
}

<INITIAL,STRING>\" {
  if(string_started == 0) {
    BEGIN(STRING);
    string_started++;
  } else {
    if(string_collect.length() > 1024) {
      string_started--;
      cool_yylval.error_msg = "String constant too long";
      string_collect = "";
      BEGIN(INITIAL);
      return ERROR;
    } else {
      string_started--;
      cool_yylval.symbol = stringtable.add_string((char *)string_collect.c_str());
      string_collect = "";
      BEGIN(INITIAL);
      return STR_CONST;
    }
  }
}

<STRING>\\[^btnf] {
  string_collect = string_collect + yytext[1];
}
<STRING>\\n {
  string_collect = string_collect + "\n";
}
<STRING>\\b {
  string_collect = string_collect + "\b";
}
<STRING>\\t {
  string_collect = string_collect + "\t";
}
<STRING>\\f {
  string_collect = string_collect + "\f";
}

<STRING>\n {
  curr_lineno++;
  cool_yylval.error_msg = "Unterminated string constant";
  string_collect = "";
  string_started--;
  BEGIN(INITIAL);
  return ERROR;
}

<STRING>\00.*?\n {
  cool_yylval.error_msg = "String contains escaped null character.";
  string_collect = "";
  string_started--;
  BEGIN(INITIAL);
  return ERROR;
}

<STRING><<EOF>> {
  cool_yylval.error_msg = "End of file, in string";
  BEGIN(INITIAL);
  return ERROR;
}

<STRING>[^\"] {
  string_collect = string_collect + yytext;
}

<INITIAL,COMMENT_NESTED>{COMMENT_START} {
  BEGIN(COMMENT_NESTED);
  comment_depth++;
}
<COMMENT_NESTED>{COMMENT_END} {
  comment_depth--;

  if(comment_depth == 0) {
    BEGIN(INITIAL);
  }
}
<INITIAL>{COMMENT_END} {
  cool_yylval.error_msg = "Unmatched *)";
  return ERROR;
}
<COMMENT_NESTED><<EOF>> {
  cool_yylval.error_msg = "End of file, no closed comment";
  BEGIN(INITIAL);
  return ERROR;
}

<COMMENT_NESTED>.
<COMMENT_NESTED>\n {
  curr_lineno++;
}


<INITIAL>{SINGLE_COMMENT_START} {
  BEGIN(SINGLE_COMMENT);
}

<SINGLE_COMMENT>. {
}

<SINGLE_COMMENT>\n {
  curr_lineno++;

  BEGIN(INITIAL);
}

\n { curr_lineno++; }

. {
  cool_yylval.error_msg = yytext;
  return ERROR;
}


<<EOF>>    yyterminate();
 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */


%%
