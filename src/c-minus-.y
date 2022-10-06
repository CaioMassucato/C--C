/* Verificando a sintaxe de programas segundo nossa GLC-exemplo */

%{
#include <stdio.h>
#include <string.h>
#include "src/vector.h"

#define TRUE 1
#define FALSE 0

//DEFINICOES DA ANALISE
#define REPORT TRUE
#define REPORT_TM TRUE

//INSTRUCTIONS TYPE
#define RO 0
#define RM 1

//RO INSTRUCTIONS
//RO r,s,t
#define HALT "HALT"
#define IN "IN"
#define OUT "OUT"
#define ADD "ADD"
#define SUB "SUB"
#define MUL "MUL"
#define DIV "DIV"

//RM INSTRUCTIONS
//RM r,d(s)
#define LD "LD"
#define LDA "LDA"
#define LDC "LDC"
#define ST "ST"
#define JLT "JLT"
#define JLE "JLE"
#define JGE "JGE"
#define JGT "JGT"
#define JEQ "JEQ"
#define JNE "JNE"

//TINY MACHINE REGISTERS
#define ac 0
#define ac1 1
#define gp 5
#define mp 6
#define pcreg 7

int cont_declr_var_linha = 0;
int cont_declr_tot = 0;
int instruction_counter = 0;
int factor = 1;

int do_semantics = 1;
int do_code = 1;

extern yylineno;
extern FILE *yyin;
extern FILE *yyout;

vector_p TS;
vector_p ExpInstruction_list;
vector_p Location_stack;
vector_p need_stack;

typedef struct _instruction{
	char op[5];
	int kind;
	int r;
	int s;
	int t;
	int hasP;
}Instruction;

Instruction cria_Instruction(int kind,char *op , int r, int s, int t, int hasP);

Instruction cria_Instruction(int kind, char *op, int r, int s, int t, int hasP)
{
	Instruction i;
	i.kind = kind;
	strcpy(i.op,op);
	i.r = r;
	i.s = s;
	i.t = t;
	i.hasP = hasP;
	return i;
}

typedef struct _simbolo{
	char id[9];
	char tipo[6];
	int declarado;
	int usado;
	int qtd_usado;
	char kind[6];
}Simbolo;

void cria_Simbolo(char* id,char* kind);

//CRIACAO DE CODIGO
void do_popExpression();
void storeVAR(char *id);
void loadVAR(char *id);
void emitInstruction(Instruction inst);
void emitComment(char *com);
void emitBackup();
int emitRestore();

//TABELA DE SIMBOLOS MANAGER
void insereTS(Simbolo s);
int busca_Simbolo(char *name, char *kind);
int hoare(int s, int n);
void order(int s, int n);

//REPORTS
void report(int sint_erro);
//
// Guarda posicao do pc reg
void emitBackup()
{
	vector_add(Location_stack,(void*)&instruction_counter,sizeof(int));
}

// Libera posicao pc reg
int emitRestore()
{
	int *i;
	i = (int*)vector_get(Location_stack,Location_stack->length-1);
	return *i;
}

void emitComment(char *com)
{
	fprintf(yyout,"* %s\n", com);
}
void emitInstruction(Instruction inst)
{
	if(do_code)
	{
		switch(inst.kind)
		{
			default:
				break;
			case RO:
				fprintf(yyout,"%3d: %5s %d,%d,%d\n",instruction_counter++,inst.op,inst.r,inst.s,inst.t);
				break;
			case RM:
				fprintf(yyout,"%3d: %5s %d,%d(%d)\n",instruction_counter++,inst.op,inst.r,inst.t,inst.s);
				break;
		}
	}
}

void storeVAR(char *id)
{
	int posicao = busca_Simbolo(id,"var");
	if(posicao!=-1)
	{
		Simbolo *s = (Simbolo *)vector_get(TS,posicao);
		Instruction inst;
		inst = cria_Instruction(RM,ST,ac,gp,posicao,FALSE);
		emitInstruction(inst);
	}
}

// Checa na pilha se precisa pegar algum valor
void do_popExpression()
{
	Instruction *i;
	if(ExpInstruction_list->length>1)
	{
		i = (Instruction*)vector_get(ExpInstruction_list,ExpInstruction_list->length-1);
		emitInstruction(*i);
		i = NULL;
		vector_remove(ExpInstruction_list,ExpInstruction_list->length-1);
	}
	emitInstruction(cria_Instruction(RM,LDA,ac1,0,ac,FALSE));
	if(ExpInstruction_list->length>0)
	{
		i = (Instruction*)vector_get(ExpInstruction_list,ExpInstruction_list->length-1);
		emitInstruction(*i);
		i=NULL;
		vector_remove(ExpInstruction_list,ExpInstruction_list->length-1);
	}
}

void loadVAR(char* id)
{
	int posicao = busca_Simbolo(id,"var");
	Simbolo *s = (Simbolo *)vector_get(TS,posicao);
	Instruction inst;
	inst = cria_Instruction(RM,LD,ac,gp,posicao,FALSE);
	vector_add(ExpInstruction_list,(void*)&inst,sizeof(Instruction));
}

void insereTS(Simbolo s)
{
	vector_add(TS,(void*)&s,sizeof(Simbolo));
}

void cria_Simbolo(char * id,char *kind)
{
	int posicao = busca_Simbolo(id,kind);
	if(posicao==-1) //Adiciona na lista
	{
		if(strcmp(kind,"var")==0)
			cont_declr_var_linha++;
		else
			cont_declr_tot++;
		Simbolo s;
		strcpy(s.tipo,"undef");
		strcpy(s.id,id);
		strcpy(s.kind,kind);
		s.declarado = TRUE;
		s.usado = FALSE;
		s.qtd_usado=0;
		insereTS(s);
	}
	else //Se ja existe marca que foi declarado mais de uma vez
	{
		Simbolo *s = (Simbolo*)vector_get(TS,posicao);
		s->declarado++;
	}
}

void marcausado_Simbolo(char* id, char *kind)
{
	int posicao = busca_Simbolo(id,kind);
	if(posicao == -1) //Se o simbolo nao existe fala que foi usado sem declarar
	{
		Simbolo s;
		strcpy(s.id,id);
		strcpy(s.kind,kind);
		strcpy(s.tipo,"undef");
		s.declarado = FALSE;
		s.usado = TRUE;
		s.qtd_usado += factor;
		cont_declr_tot++;
		insereTS(s);
	}
	else //Se ja existe marca usado
	{
		Simbolo *s = (Simbolo *)vector_get(TS,posicao);
		s->usado = 1;
		s->qtd_usado += factor;
	}
}

int busca_Simbolo(char *name,char *kind)
{
	int i=0;
	for(i=0;i<TS->length;i++)
	{
		Simbolo *s = (Simbolo*)vector_get(TS,i);
		if(strcmp(name,s->id)==0 && strcmp(s->kind,kind)==0)
		{
			return i;
		}
	}
	return -1;
}

int hoare(int s, int n)
{
	Simbolo *x = (Simbolo*) vector_get(TS,s);
    int i = s-1;
    int j = n;
    Simbolo *atual;
    while(1){
        do{
            j--;
           	atual = (Simbolo*) vector_get(TS,j);
        }while(atual->qtd_usado > x->qtd_usado);
        do{
            i++;            
            atual = (Simbolo*) vector_get(TS,i);
        }while(atual->qtd_usado < x->qtd_usado);
        if(i < j) vector_swap(TS,i, j);
        else return j;
    }
}

void order(int s,int n)
{
	int q;
	if(s < n)
	{
		q = hoare(s,n);
		order(s,q);
		order(q+1,n);
	}
}

%}
%union {
char *cadeia;
char *tipo;
char *operador;
int inum;
}

%token <cadeia> ID
%token <inum> INTEIRO
%token PRINT
%token READ
%token <operador>ASSIGN
%token <operador>OADD
%token <operador>OMULT
%token <operador>REL
%token RPT
%token IF
%token ELSE
%token THEN
%token DEL_BLOCO_ABRE
%token DEL_BLOCO_FECHA
%token <tipo> TIPO

%%
/* Regras definindo a GLC e acoes correspondentes */
programa:
	{if(REPORT_TM && do_code) emitComment("START PROGRAM");} lista_declaracao {;};

lista_declaracao:
	declaracao {;}
	| lista_declaracao declaracao {;};

declaracao:
	declaracao_var {;}
	| declaracao_fun {;};

declaracao_var:
	TIPO lista_declaracao_var 
	{
		if(do_semantics)
		{
			cont_declr_tot += cont_declr_var_linha;
			int i=0;
			for(i=0;i<cont_declr_var_linha;i++) //update variavel com seu tipo
			{
				Simbolo *s = (Simbolo*)vector_get(TS,cont_declr_tot - i - 1);
				strcpy(s->tipo,$TIPO);
			}
			cont_declr_var_linha = 0;
		}
			free($TIPO);
	};

lista_declaracao_var: 
	ID ';' 
	{
		if(do_semantics)
			cria_Simbolo($ID,"var");
		free($ID);
	}
	| ID ',' lista_declaracao_var 
	{
		if(do_semantics)
			cria_Simbolo($ID,"var");
		free($ID);
	};

declaracao_fun:
	ID '('')'
	{
		if(do_semantics)
			cria_Simbolo($ID,"fun");
		free($ID);
	} cmpst_statement{;};

cmpst_statement:
	DEL_BLOCO_ABRE lista_statement DEL_BLOCO_FECHA{;};

lista_statement:
	statement {;}
	| statement lista_statement {;};

statement:
	exp_statement {;}
	| sel_statement {;}
	| rpt_statement {;}
	| print_statement {;}
	| read_statement {;}
	| cmpst_statement {;};

print_statement:
	PRINT '(' exp ')' ';' 
	{
		if(ExpInstruction_list->length)
		{
			Instruction *i = (Instruction*)vector_get(ExpInstruction_list,ExpInstruction_list->length-1);
			emitInstruction(*i);
			vector_remove(ExpInstruction_list,ExpInstruction_list->length-1);
		}
		emitInstruction(cria_Instruction(RO,OUT,ac,0,0,FALSE));
	};

read_statement:
	READ '(' ID ')' ';'
	{
		if(do_semantics)
			marcausado_Simbolo($ID,"var");
		emitInstruction(cria_Instruction(RO,IN,ac,0,0,FALSE));
		storeVAR($ID);
		free($ID);
	};

sel_statement:
	IF '(' exp ')' THEN {emitBackup();instruction_counter++;} statement
	{
		int i = instruction_counter;
		instruction_counter = emitRestore();
		vector_remove(Location_stack,Location_stack->length-1);
		emitInstruction(cria_Instruction(RM,JEQ,ac,pcreg,i - instruction_counter - 1,FALSE));
		instruction_counter = i;
	}
	| IF '(' exp ')' {emitBackup();instruction_counter++;} statement
	{
		int i = instruction_counter;
		instruction_counter = emitRestore();
		vector_remove(Location_stack,Location_stack->length-1);
		emitInstruction(cria_Instruction(RM,JEQ,ac,pcreg,i - instruction_counter,FALSE));
		instruction_counter = i;
	}
	ELSE {emitBackup();instruction_counter++;} statement
	{
		int i = instruction_counter;
		instruction_counter = emitRestore();
		vector_remove(Location_stack,Location_stack->length-1);
		emitInstruction(cria_Instruction(RM,LDA,pcreg,pcreg,i - instruction_counter - 1,FALSE));
		instruction_counter = i;
	};
rpt_statement:
	RPT {factor*=10;emitBackup();}'(' exp ')'{factor/=10;emitBackup();instruction_counter++;} statement 
	{
			int i = instruction_counter;
			instruction_counter = emitRestore();
			vector_remove(Location_stack,Location_stack->length-1);
			emitInstruction(cria_Instruction(RM,JEQ,ac,pcreg,i - instruction_counter,FALSE));
			instruction_counter = i;
			int aux;
			aux = emitRestore();
			vector_remove(Location_stack,Location_stack->length-1);
			emitInstruction(cria_Instruction(RM,LDA,pcreg,pcreg,aux-instruction_counter-1,FALSE));
	};

exp_statement:
	exp ';'{;}
	| ';' {;};

exp:
	ID {if(do_semantics) marcausado_Simbolo($ID,"var");} ASSIGN exp
	{
		if(ExpInstruction_list->length>=1)
		{
			Instruction *i = (Instruction*)vector_get(ExpInstruction_list,ExpInstruction_list->length-1);
			emitInstruction(*i);
			vector_remove(ExpInstruction_list,ExpInstruction_list->length-1);
		}
		storeVAR($ID);
		free($ID);
		free($ASSIGN);
	}
	| exp_simples {;};

exp_simples:
	exp_add REL exp_add
	{
		do_popExpression();
		if(strcmp($REL,"<")==0)
		{
			emitInstruction(cria_Instruction(RO,SUB,ac,ac,ac1,FALSE));		
			emitInstruction(cria_Instruction(RM,JLT,ac,pcreg,2,FALSE));
		}
		else if(strcmp($REL,">")==0)
		{
			emitInstruction(cria_Instruction(RO,SUB,ac,ac,ac1,FALSE));
			emitInstruction(cria_Instruction(RM,JGT,ac,pcreg,2,FALSE));
		}
		else if(strcmp($REL,"<=")==0)
		{
			emitInstruction(cria_Instruction(RO,SUB,ac,ac,ac1,FALSE));
			emitInstruction(cria_Instruction(RM,JLE,ac,pcreg,2,FALSE));
		}
		else if(strcmp($REL,">=")==0)
		{
			emitInstruction(cria_Instruction(RO,SUB,ac,ac,ac1,FALSE));
			emitInstruction(cria_Instruction(RM,JGE,ac,pcreg,2,FALSE));
		}
		else if(strcmp($REL,"==")==0)
		{
			emitInstruction(cria_Instruction(RO,SUB,ac,ac,ac1,FALSE));
			emitInstruction(cria_Instruction(RM,JEQ,ac,pcreg,2,FALSE));
		}
		else if(strcmp($REL,"!=")==0)
		{
			emitInstruction(cria_Instruction(RO,SUB,ac,ac,ac1,FALSE));
			emitInstruction(cria_Instruction(RM,JNE,ac,pcreg,2,FALSE));
		}
		else if(strcmp($REL,"&&")==0)
		{
			emitInstruction(cria_Instruction(RO,MUL,ac,ac,ac1,FALSE));
			emitInstruction(cria_Instruction(RM,JNE,ac,pcreg,2,FALSE));
		}
		else if(strcmp($REL,"||")==0)
		{
			emitInstruction(cria_Instruction(RO,ADD,ac,ac,ac1,FALSE));
			emitInstruction(cria_Instruction(RM,JNE,ac,pcreg,2,FALSE));
		}
		else
		{
			if(REPORT_TM) emitComment("Undefined Expression");
		}
		emitInstruction(cria_Instruction(RM,LDC,ac,ac,0,FALSE));
		emitInstruction(cria_Instruction(RM,LDA,pcreg,pcreg,1,FALSE));
		emitInstruction(cria_Instruction(RM,LDC,ac,ac,1,FALSE));
		Instruction inst;
		free($REL);
	}
	| exp_add {;};

exp_add:
	exp_add OADD term
	{
		do_popExpression();
		if(strcmp($OADD,"+")==0)
		{
			//ADD
			emitInstruction(cria_Instruction(RO,ADD,ac,ac,ac1,FALSE));
		}
		else
		{
			//SUB
			emitInstruction(cria_Instruction(RO,SUB,ac,ac,ac1,0));
		}
		
		// Guarda valores na pilha caso existam mais de dois operandos
		// Espera proximo operando para que trate os valores inseridos na pilha
		free($OADD);
	}
	| term {;};

term:
	term OMULT fator
	{
		do_popExpression();
		if(strcmp($OMULT,"*")==0)
		{
			emitInstruction(cria_Instruction(RO,MUL,ac,ac,ac1,FALSE));
		}
		else
		{
			emitInstruction(cria_Instruction(RO,DIV,ac,ac,ac1,FALSE));
		}
		Instruction inst;
		
		free($OMULT);
	}
	| fator {;};

fator:
	'('{int i = 1;vector_add(need_stack,(void*)&i,sizeof(int));} exp ')' {vector_remove(need_stack,need_stack->length-1);}
	| call {;}
	| ID 
	{
		if(do_semantics)
			marcausado_Simbolo($ID,"var");
		loadVAR($ID);
		free($ID);
	}
	| INTEIRO
	{
		Instruction inst = cria_Instruction(RM,LDC,ac,0,$INTEIRO,FALSE);
		vector_add(ExpInstruction_list,(void*)&inst,sizeof(Instruction));
	};

call:
	ID '('')'
	{
		if(do_semantics)
			marcausado_Simbolo($ID,"fun");
		free($ID);
	};
%%
int main (int argc, char *argv[]) 
{
	int sint_erro;
	TS = create_vector();
	ExpInstruction_list = create_vector();
	Location_stack = create_vector();
	need_stack = create_vector();
	char infile_name[100];
	char outfile_name[100];
	strcpy(infile_name,argv[1]);
	char *pch = strrchr(infile_name,'/');
	if(pch == NULL) strcpy(outfile_name,infile_name);
	else strcpy(outfile_name,pch+1);
	pch = strrchr(infile_name,'.');
	if(pch == NULL)	{strcat(infile_name,".c--");}
	else 
	{
		char aux[100] = "";
		strncpy(aux,outfile_name,strlen(outfile_name) - strlen(pch));
		strcpy(outfile_name,aux);
	}
	strcat(outfile_name,".tm");
	yyin = fopen(infile_name,"r");
	
	do_semantics = 1;
	do_code = 0;
	sint_erro = yyparse();
	rewind(yyin);
	do_code = 1;
	do_semantics = 0;
	instruction_counter = 0;
	report(sint_erro);
	if(TS->length!=0 && !sint_erro)
	{
		if(do_code)
		{
			if(argc < 3)
				yyout = fopen(outfile_name,"w");
			else
				yyout = fopen(argv[2],"w");
			if(REPORT_TM) emitComment("PRELUDIO");
			emitInstruction(cria_Instruction(RM,LD,6,0,0,FALSE));
			emitInstruction(cria_Instruction(RM,ST,0,0,0,FALSE));
			yyparse();
			if(REPORT_TM) emitComment("STOP");
			emitInstruction(cria_Instruction(RO,HALT,0,0,0,FALSE));
			printf("Contagem instr: %d\n",instruction_counter);
			fclose(yyout);
		}
	}
	fclose(yyin);
	destroy_vector(TS);
	destroy_vector(ExpInstruction_list);
	destroy_vector(Location_stack);
	destroy_vector(need_stack);
	return 0;
}

void report(int sint_erro)
{
	order(0,TS->length);
	int i = 0;
	for(i=0;i<TS->length;i++)
	{
		Simbolo *s = (Simbolo*)vector_get(TS,i);
	}
	
	if(REPORT)
	{
		printf("----Tabela de Símbolos----\nDeclarações: %d\n",cont_declr_tot);
		printf("Tipo Decl.\tType\tID\tDeclarado\tUsado\n");
		for(i=0;i<TS->length;i++)
		{
			Simbolo *s = (Simbolo*)vector_get(TS,i);
			printf("%s\t\t%s\t%s\t%d\t\t%d\n",s->kind,s->tipo,s->id,s->declarado,s->usado);
		}
	}
}

yyerror (s) {}
