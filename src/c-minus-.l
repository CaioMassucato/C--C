%option noyywrap
%option yylineno
%{
#include "c-minus-.tab.h"
%}
%%

("abre"|"{")							{return DEL_BLOCO_ABRE;}
("fecha"|"}")							{return DEL_BLOCO_FECHA;}
("int")									{yylval.tipo= (char *) strdup(yytext);return TIPO;}
("then")								{return THEN;}
("while")								{return RPT;}
("print")								{return PRINT;}
("read")								{return READ;}
("if")									{return IF;}
("else")								{return ELSE;}
("<-"|"=")								{yylval.operador = (char*) strdup(yytext);return ASSIGN;}
("+"|"-")								{yylval.operador = (char*) strdup(yytext);return OADD;}
("*"|"/")								{yylval.operador = (char*) strdup(yytext);return OMULT;}
("<"|">"|"=="|">="|"<="|"!="|"&&"|"||")	{yylval.operador = (char*) strdup(yytext);return REL;}
[a-z]{1,8} 								{yylval.cadeia= (char *) strdup(yytext);return ID;}
[0-9]+									{yylval.inum = atoi(yytext);return INTEIRO;}
"/*"(.|\n)*"*/"							{;}
[ \n\t\r]+								{;}
.										{return yytext[0];}

%%
