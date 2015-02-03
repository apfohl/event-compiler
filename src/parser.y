%include
{
    #include <stdio.h>
    #include <stdlib.h>
    #include <assert.h>
    #include <string.h>
    #include <tree.h>
    #include "ast.h"
    #include "parser_state.h"

    struct stack *allocated_nodes = NULL;
}

%token_type { const char * }
%token_destructor {
    free((char *)$$);
    parser_state->state = parser_state->state;
}

%type translation_unit { struct node * }
%type declaration_sequence { struct node * }
%type declaration { struct node * }
%type event_inheritance { struct node * }
%type rule_declaration { struct node * }
%type rule_signature { struct node * }
%type event_sequence { struct node * }
%type predicate_sequence { struct node * }
%type function_definition { struct node * }
%type parameter_list { struct node * }
%type parameter { struct node * }
%type function_call { struct node * }
%type argument_sequence { struct node * }
%type event_definition { struct node * }
%type initializer_sequence { struct node * }
%type initializer { struct node * }
%type vector { struct node * }
%type component_sequence { struct node * }
%type expression_sequence { struct node * }
%type expression { struct node * }
%type additive_expression { struct node * }
%type addition { struct node * }
%type multiplicative_expression { struct node * }
%type multiplication { struct node * }
%type negation { struct node * }
%type primary_expression { struct node * }
%type atomic { struct node * }

%extra_argument { struct parser_state *parser_state }

%syntax_error
{
    fprintf(stderr, "%s\n", "Error parsing input.");
    parser_state->state = ERROR;
}

translation_unit(NODE) ::= declaration_sequence(DS).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_TRANSLATION_UNIT;
    payload->alternative = ALT_DECLARATION_SEQUENCE;
    NODE = tree_create_node(payload, 1, DS);
    parser_state->root = NODE;
    parser_state->state = OK;
    while (stack_pop(&allocated_nodes));
}
translation_unit ::= error.
{
    struct node *temp = NULL;
    while ((temp = stack_pop(&allocated_nodes)) != NULL) {
        payload_free(temp->payload);
        free(temp);
    }
    parser_state->state = ERROR;
    parser_state->root = NULL;
}

declaration_sequence(NODE) ::= declaration_sequence(DS) declaration(D).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_DECLARATION_SEQUENCE;
    payload->alternative = ALT_DECLARATION;
    NODE = malloc(sizeof(struct node) + sizeof(struct node *) * (DS->childc + 1));
    NODE->payload = payload;
    NODE->childc = DS->childc + 1;
    memcpy(NODE->childv, DS->childv, sizeof(struct node *) * DS->childc);
    NODE->childv[NODE->childc - 1] = D;
    payload_free(DS->payload);
    DS->payload = NULL;
    stack_pop(&allocated_nodes);
    stack_push(&allocated_nodes, NODE);
    free(DS);
}
declaration_sequence(NODE) ::= declaration(D).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_DECLARATION_SEQUENCE;
    payload->alternative = ALT_DECLARATION;
    NODE = tree_create_node(payload, 1, D);
    stack_push(&allocated_nodes, NODE);
}

declaration(NODE) ::= event_inheritance(EI) SEMIC.
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_DECLARATION;
    payload->alternative = ALT_EVENT_INHERITANCE;
    NODE = tree_create_node(payload, 1, EI);
    stack_push(&allocated_nodes, NODE);
}
declaration(NODE) ::= rule_declaration(RD) SEMIC.
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_DECLARATION;
    payload->alternative = ALT_RULE_DECLARATION;
    NODE = tree_create_node(payload, 1, RD);
    stack_push(&allocated_nodes, NODE);
}
declaration(NODE) ::= function_definition(FD) SEMIC.
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_DECLARATION;
    payload->alternative = ALT_FUNCTION_DEFINITION;
    NODE = tree_create_node(payload, 1, FD);
    stack_push(&allocated_nodes, NODE);
}

// event_inheritance
event_inheritance(NODE) ::= TYPE(TL) EXTENDS TYPE(TR).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_EVENT_INHERITANCE;
    payload->alternative = ALT_TYPE;
    payload->event_inheritance.type[0] = malloc(strlen(TL) + 1);
    strcpy((char *)(payload->event_inheritance.type[0]), TL);
    payload->event_inheritance.type[1] = malloc(strlen(TR) + 1);
    strcpy((char *)(payload->event_inheritance.type[1]), TR);
    NODE = tree_create_node(payload, 0);
    stack_push(&allocated_nodes, NODE);
    free((char *)TL);
    free((char *)TR);
}

// rule_declaration
rule_declaration(NODE) ::= TYPE(T) COLON rule_signature(RS) RARROW IDENTIFIER(I).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_RULE_DECLARATION;
    payload->alternative = ALT_RULE_SIGNATURE;
    payload->rule_declaration.type = malloc(strlen(T) + 1);
    strcpy((char *)(payload->rule_declaration.type), T);
    payload->rule_declaration.identifier = malloc(strlen(I) + 1);
    strcpy((char *)(payload->rule_declaration.identifier), I);
    NODE = tree_create_node(payload, 1, RS);
    stack_push(&allocated_nodes, NODE);
    free((char *)T);
    free((char *)I);
}

rule_signature(NODE) ::= LBRACKET event_sequence(ES) COLON predicate_sequence(PS) RBRACKET.
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_RULE_SIGNATURE;
    payload->alternative = ALT_EVENT_SEQUENCE;
    NODE = tree_create_node(payload, 2, ES, PS);
    stack_push(&allocated_nodes, NODE);
}
rule_signature(NODE) ::= LBRACKET predicate_sequence(PS) RBRACKET.
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_RULE_SIGNATURE;
    payload->alternative = ALT_PREDICATE_SEQUENCE;
    NODE = tree_create_node(payload, 1, PS);
    stack_push(&allocated_nodes, NODE);
}
rule_signature(NODE) ::= LBRACKET RBRACKET.
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_RULE_SIGNATURE;
    payload->alternative = ALT_NONE;
    NODE = tree_create_node(payload, 0);
    stack_push(&allocated_nodes, NODE);
}

event_sequence(NODE) ::= event_sequence(ES) COMMA TYPE(T).
{
    struct payload *payload = ES->payload;
    payload->event_sequence.count += 1;
    payload->event_sequence.type =
        realloc(payload->event_sequence.type,
            payload->event_sequence.count * sizeof(char *));
    payload->event_sequence.type[payload->event_sequence.count - 1] =
        malloc(strlen(T) + 1);
    strcpy((char *)(payload->event_sequence.type[payload->event_sequence.count - 1]), T);
    NODE = ES;
    free((char *)T);
}
event_sequence(NODE) ::= TYPE(T).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_EVENT_SEQUENCE;
    payload->alternative = ALT_TYPE;
    payload->event_sequence.count = 1;
    payload->event_sequence.type = malloc(sizeof(char *));
    payload->event_sequence.type[0] = malloc(strlen(T) + 1);
    strcpy((char *)(payload->event_sequence.type[0]), T);
    NODE = tree_create_node(payload, 0);
    stack_push(&allocated_nodes, NODE);
    free((char *)T);
}

predicate_sequence(NODE) ::= predicate_sequence(PS) COMMA IDENTIFIER(I).
{
    struct payload *payload = PS->payload;
    payload->predicate_sequence.count += 1;
    payload->predicate_sequence.identifier =
        realloc(payload->predicate_sequence.identifier,
            payload->predicate_sequence.count * sizeof(char *));
    payload->predicate_sequence.identifier[payload->predicate_sequence.count - 1] =
        malloc(strlen(I) + 1);
    strcpy((char *)(payload->predicate_sequence.identifier[payload->predicate_sequence.count - 1]), I);
    NODE = PS;
    free((char *)I);
}
predicate_sequence(NODE) ::= IDENTIFIER(I).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_PREDICATE_SEQUENCE;
    payload->alternative = ALT_IDENTIFIER;
    payload->predicate_sequence.count = 1;
    payload->predicate_sequence.identifier = malloc(sizeof(char *));
    payload->predicate_sequence.identifier[0] = malloc(strlen(I) + 1);
    strcpy((char *)(payload->predicate_sequence.identifier[0]), I);
    NODE = tree_create_node(payload, 0);
    stack_push(&allocated_nodes, NODE);
    free((char *)I);
}

// function_definition
function_definition(NODE) ::= TYPE(T) IDENTIFIER(I) LPAREN RPAREN DEF expression(E).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_FUNCTION_DEFINITION;
    payload->alternative = ALT_EXPRESSION;
    payload->function_definition.type = malloc(strlen(T) + 1);
    strcpy((char *)(payload->function_definition.type), T);
    payload->function_definition.identifier = malloc(strlen(I) + 1);
    strcpy((char *)(payload->function_definition.identifier), I);
    NODE = tree_create_node(payload, 1, E);
    stack_push(&allocated_nodes, NODE);
    free((char *)T);
    free((char *)I);
}
function_definition(NODE) ::= TYPE(T) IDENTIFIER(I) LPAREN parameter_list(PL) RPAREN DEF expression(E).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_FUNCTION_DEFINITION;
    payload->alternative = ALT_PARAMETER_LIST;
    payload->function_definition.type = malloc(strlen(T) + 1);
    strcpy((char *)(payload->function_definition.type), T);
    payload->function_definition.identifier = malloc(strlen(I) + 1);
    strcpy((char *)(payload->function_definition.identifier), I);
    NODE = tree_create_node(payload, 2, PL, E);
    stack_push(&allocated_nodes, NODE);
    free((char *)T);
    free((char *)I);
}

parameter_list(NODE) ::= parameter_list(PL) COMMA parameter(P).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_INITIALIZER_SEQUENCE;
    payload->alternative = ALT_INITIALIZER;
    NODE = malloc(sizeof(struct node) + sizeof(struct node *) * (PL->childc + 1));
    NODE->payload = payload;
    NODE->childc = PL->childc + 1;
    memcpy(NODE->childv, PL->childv, sizeof(struct node *) * PL->childc);
    NODE->childv[NODE->childc - 1] = P;
    payload_free(PL->payload);
    PL->payload = NULL;
    stack_pop(&allocated_nodes);
    stack_push(&allocated_nodes, NODE);
    free(PL);
}
parameter_list(NODE) ::= parameter(P).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_PARAMETER_LIST;
    payload->alternative = ALT_PARAMETER;
    NODE = tree_create_node(payload, 1, P);
    stack_push(&allocated_nodes, NODE);
}

parameter(NODE) ::= TYPE(T) IDENTIFIER(I).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_PARAMETER;
    payload->alternative = ALT_IDENTIFIER;
    payload->parameter.type = malloc(strlen(T) + 1);
    strcpy((char *)(payload->parameter.type), T);
    payload->parameter.identifier = malloc(strlen(I) + 1);
    strcpy((char *)(payload->parameter.identifier), I);
    NODE = tree_create_node(payload, 0);
    stack_push(&allocated_nodes, NODE);
    free((char *)T);
    free((char *)I);
}

// function_call
function_call(NODE) ::= IDENTIFIER(I) LPAREN argument_sequence(AS) RPAREN.
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_FUNCTION_CALL;
    payload->alternative = ALT_ARGUMENT_SEQUENCE;
    payload->function_call.identifier = malloc(strlen(I) + 1);
    strcpy((char *)(payload->function_call.identifier), I);
    NODE = tree_create_node(payload, 1, AS);
    stack_push(&allocated_nodes, NODE);
    free((char *)I);
}

argument_sequence(NODE) ::= expression_sequence(ES).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_ARGUMENT_SEQUENCE;
    payload->alternative = ALT_EXPRESSION_SEQUENCE;
    NODE = tree_create_node(payload, 1, ES);
    stack_push(&allocated_nodes, NODE);
}

// event_definition
event_definition(NODE) ::= LBRACE initializer_sequence(IS) RBRACE.
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_EVENT_DEFINITION;
    payload->alternative = ALT_INITIALIZER_SEQUENCE;
    NODE = tree_create_node(payload, 1, IS);
    stack_push(&allocated_nodes, NODE);
}

initializer_sequence(NODE) ::= initializer_sequence(IS) COMMA initializer(I).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_INITIALIZER_SEQUENCE;
    payload->alternative = ALT_INITIALIZER;
    NODE = malloc(sizeof(struct node) + sizeof(struct node *) * (IS->childc + 1));
    NODE->payload = payload;
    NODE->childc = IS->childc + 1;
    memcpy(NODE->childv, IS->childv, sizeof(struct node *) * IS->childc);
    NODE->childv[NODE->childc - 1] = I;
    payload_free(IS->payload);
    IS->payload = NULL;
    stack_pop(&allocated_nodes);
    stack_push(&allocated_nodes, NODE);
    free(IS);
}
initializer_sequence(NODE) ::= initializer(I).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_INITIALIZER_SEQUENCE;
    payload->alternative = ALT_INITIALIZER;
    NODE = tree_create_node(payload, 1, I);
    stack_push(&allocated_nodes, NODE);
}

initializer(NODE) ::= IDENTIFIER(I) ASSIGN expression(E).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_INITIALIZER;
    payload->alternative = ALT_EXPRESSION;
    payload->initializer.identifier = malloc(strlen(I) + 1);
    strcpy((char *)(payload->initializer.identifier), I);
    NODE = tree_create_node(payload, 1, E);
    stack_push(&allocated_nodes, NODE);
    free((char *)I);
}

// vector definition
vector(NODE) ::= LBRACKET component_sequence(CS) RBRACKET.
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_VECTOR;
    payload->alternative = ALT_COMPONENT_SEQUENCE;
    NODE = tree_create_node(payload, 1, CS);
    stack_push(&allocated_nodes, NODE);
}

component_sequence(NODE) ::= expression_sequence(ES).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_COMPONENT_SEQUENCE;
    payload->alternative = ALT_EXPRESSION_SEQUENCE;
    NODE = tree_create_node(payload, 1, ES);
    stack_push(&allocated_nodes, NODE);
}

// expression_sequence
expression_sequence(NODE) ::= expression_sequence(ES) COMMA expression(E).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_EXPRESSION_SEQUENCE;
    payload->alternative = ALT_EXPRESSION;
    NODE = malloc(sizeof(struct node) + sizeof(struct node *) * (ES->childc + 1));
    NODE->payload = payload;
    NODE->childc = ES->childc + 1;
    memcpy(NODE->childv, ES->childv, sizeof(struct node *) * ES->childc);
    NODE->childv[NODE->childc - 1] = E;
    payload_free(ES->payload);
    ES->payload = NULL;
    stack_pop(&allocated_nodes);
    stack_push(&allocated_nodes, NODE);
    free(ES);
}
expression_sequence(NODE) ::= expression(E).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_EXPRESSION_SEQUENCE;
    payload->alternative = ALT_EXPRESSION;
    NODE = tree_create_node(payload, 1, E);
    stack_push(&allocated_nodes, NODE);
}

// expressions
expression(NODE) ::= additive_expression(AE).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_EXPRESSION;
    payload->alternative = ALT_ADDITIVE_EXPRESSION;
    NODE = tree_create_node(payload, 1, AE);
    stack_push(&allocated_nodes, NODE);
}

additive_expression(NODE) ::= addition(A).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_ADDITIVE_EXPRESSION;
    payload->alternative = ALT_ADDITION;
    NODE = tree_create_node(payload, 1, A);
    stack_push(&allocated_nodes, NODE);
}
additive_expression(NODE) ::= multiplicative_expression(ME).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_ADDITIVE_EXPRESSION;
    payload->alternative = ALT_MULTIPLICATIVE_EXPRESSION;
    NODE = tree_create_node(payload, 1, ME);
    stack_push(&allocated_nodes, NODE);
}

addition(NODE) ::= additive_expression(AE) ADD multiplicative_expression(ME).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_ADDITION;
    payload->alternative = ALT_ADD;
    NODE = tree_create_node(payload, 2, AE, ME);
    stack_push(&allocated_nodes, NODE);
}
addition(NODE) ::= additive_expression(AE) SUB multiplicative_expression(ME).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_ADDITION;
    payload->alternative = ALT_SUB;
    NODE = tree_create_node(payload, 2, AE, ME);
    stack_push(&allocated_nodes, NODE);
}

multiplicative_expression(NODE) ::= multiplication(M).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_MULTIPLICATIVE_EXPRESSION;
    payload->alternative = ALT_MULTIPLICATION;
    NODE = tree_create_node(payload, 1, M);
    stack_push(&allocated_nodes, NODE);
}
multiplicative_expression(NODE) ::= negation(N).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_MULTIPLICATIVE_EXPRESSION;
    payload->alternative = ALT_NEGATION;
    NODE = tree_create_node(payload, 1, N);
    stack_push(&allocated_nodes, NODE);
}

multiplication(NODE) ::= multiplicative_expression(ME) MULT negation(N).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_MULTIPLICATION;
    payload->alternative = ALT_MULT;
    NODE = tree_create_node(payload, 2, ME, N);
    stack_push(&allocated_nodes, NODE);
}
multiplication(NODE) ::= multiplicative_expression(ME) DIV negation(N).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_MULTIPLICATION;
    payload->alternative = ALT_DIV;
    NODE = tree_create_node(payload, 2, ME, N);
    stack_push(&allocated_nodes, NODE);
}

negation(NODE) ::= SUB negation(N).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_NEGATION;
    payload->alternative = ALT_NEGATION;
    NODE = tree_create_node(payload, 1, N);
    stack_push(&allocated_nodes, NODE);
}
negation(NODE) ::= primary_expression(PE).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_NEGATION;
    payload->alternative = ALT_PRIMARY_EXPRESSION;
    NODE = tree_create_node(payload, 1, PE);
    stack_push(&allocated_nodes, NODE);
}

primary_expression(NODE) ::= LPAREN expression(E) RPAREN.
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_PRIMARY_EXPRESSION;
    payload->alternative = ALT_EXPRESSION;
    NODE = tree_create_node(payload, 1, E);
    stack_push(&allocated_nodes, NODE);
}
primary_expression(NODE) ::= atomic(A).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_PRIMARY_EXPRESSION;
    payload->alternative = ALT_ATOMIC;
    NODE = tree_create_node(payload, 1, A);
    stack_push(&allocated_nodes, NODE);
}

atomic(NODE) ::= IDENTIFIER(IL) DOT IDENTIFIER(IR).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_ATOMIC;
    payload->alternative = ALT_IDENTIFIER;
    payload->atomic.identifier[0] = malloc(strlen(IL) + 1);
    payload->atomic.identifier[1] = malloc(strlen(IR) + 1);
    strcpy((char *)(payload->atomic.identifier[0]), IL);
    strcpy((char *)(payload->atomic.identifier[1]), IR);
    NODE = tree_create_node(payload, 0);
    stack_push(&allocated_nodes, NODE);
    free((char *)IL);
    free((char *)IR);
}
atomic(NODE) ::= IDENTIFIER(I).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_ATOMIC;
    payload->alternative = ALT_IDENTIFIER;
    payload->atomic.identifier[0] = malloc(strlen(I) + 1);
    payload->atomic.identifier[1] = NULL;
    strcpy((char *)(payload->atomic.identifier[0]), I);
    NODE = tree_create_node(payload, 0);
    stack_push(&allocated_nodes, NODE);
    free((char *)I);
}
atomic(NODE) ::= NUMBER(N).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_ATOMIC;
    payload->alternative = ALT_NUMBER;
    payload->atomic.number = atof(N);
    NODE = tree_create_node(payload, 0);
    stack_push(&allocated_nodes, NODE);
    free((char *)N);
}
atomic(NODE) ::= vector(V).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_ATOMIC;
    payload->alternative = ALT_VECTOR;
    NODE = tree_create_node(payload, 1, V);
    stack_push(&allocated_nodes, NODE);
}
atomic(NODE) ::= event_definition(ED).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_ATOMIC;
    payload->alternative = ALT_EVENT_DEFINITION;
    NODE = tree_create_node(payload, 1, ED);
    stack_push(&allocated_nodes, NODE);
}
atomic(NODE) ::= function_call(FC).
{
    struct payload *payload = malloc(sizeof(struct payload));
    payload->type = N_ATOMIC;
    payload->alternative = ALT_FUNCTION_CALL;
    NODE = tree_create_node(payload, 1, FC);
    stack_push(&allocated_nodes, NODE);
}
