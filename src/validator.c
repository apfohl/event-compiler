#include <stdlib.h>
#include <stack.h>
#include <string.h>
#include "ast.h"
#include "validator.h"

enum types {
    T_NUMBER = 1,
    T_BOOL,
    T_VECTOR,
    T_EVENT,
    T_GENERIC_EVENT
};

static enum types *new_type(enum types type) {
    enum types *t = malloc(sizeof(enum types));
    *t = type;
    return t;
}

int validate(struct node *root)
{
    struct tree_iterator *it = tree_iterator_init(&root, POSTORDER);
    struct node *temp = NULL;
    struct payload *payload = NULL;
    struct stack *type_stack = NULL;
    enum types *op2 = NULL;
    enum types *op1 = NULL;
    struct node *tempnode1 = NULL;
    struct node *tempnode2 = NULL;
    char *typename1 = NULL;
    char *typename2 = NULL;
    int success = 1;

    while ((temp = tree_iterator_next(it)) != NULL) {
        payload = (struct payload *)temp->payload;
        switch (payload->type) {
            case N_TRANSLATION_UNIT:
                break;
            case N_DECLARATION_SEQUENCE:
                break;
            case N_DECLARATION:
                break;
            case N_EVENT_INHERITANCE:
                break;
            case N_RULE_DECLARATION:
                break;
            case N_RULE_SIGNATURE:
                /* loop over predicates */
                ;
                int predicate_sequence_index;
                if (payload->alternative == ALT_EVENT_SEQUENCE){
                    predicate_sequence_index = 1;
                } else {
                    continue;
                }
                for (int i = 0; i < temp->childv[predicate_sequence_index]->childc; i++) {
                    /* get predicate definition */
                    tempnode1 = ((struct payload *)(temp->childv[predicate_sequence_index]->childv[i]->payload))->predicate.ref;
                    if (tempnode1->childc == 2) {
                        /* loop over parameters */
                        for (int j = 0; j < tempnode1->childv[0]->childc; j++) {
                            tempnode2 = tempnode1->childv[0]->childv[j];
                            typename1 = ((struct payload *)(tempnode2->payload))->parameter.type;
                            typename2 = ((struct payload *)(temp->childv[0]->payload))->event_sequence.type[j];
                            if (strcmp(typename1, typename2) != 0) {
                                success = 0;
                                break;
                            }
                        }

                        if (!success) {
                            break;
                        }
                    } else if (temp->childc != 1) {
                        success = 0;
                        break;
                    }
                }
                break;
            case N_EVENT_SEQUENCE:
                break;
            case N_PREDICATE_SEQUENCE:
                break;
            case N_PREDICATE:
                break;
            case N_PREDICATE_DEFINITION:
                op1 = stack_pop(&type_stack);
                if (*op1 != T_BOOL) {
                    success = 0;
                }
                free(op1);
                op1 = NULL;
                break;
            case N_FUNCTION_DEFINITION:
                op1 = stack_pop(&type_stack);
                if (*op1 == T_EVENT) {
                    typename1 = stack_pop(&type_stack);
                    if (strcmp(typename1, payload->function_definition.type) != 0) {
                        success = 0;
                    }
                } else if (*op1 != T_GENERIC_EVENT) {
                    success = 0;
                }
                free(op1);
                op1 = NULL;
                break;
            case N_PARAMETER_LIST:
                break;
            case N_PARAMETER:
                break;
            case N_FUNCTION_CALL:
                // get corresponding function definition from scope
                tempnode1 = ((struct payload *)payload)->function_call.ref;

                // get expression sequence via argument sequence
                tempnode2 = temp->childv[0]->childv[0];

                // check number of parameters
                if (tempnode1->childv[0]->childc == tempnode2->childc) {
                    // check parameter types against function definition
                    for (int i = 0; i < tempnode2->childc; i++) {
                        enum types *type = stack_pop(&type_stack);
                        if (*type == T_EVENT) {
                            typename1 = stack_pop(&type_stack);
                            typename2 = ((struct payload *)tempnode1->childv[0]->childv[i]->payload)->parameter.type;
                            if (strcmp(typename1, typename2) != 0) {
                                success = 0;
                                free(type);
                                break;
                            }
                        } else {
                            success = 0;
                            free(type);
                            break;
                        }

                        free(type);
                    }
                } else {
                    success = 0;
                    break;
                }

                if (success) {
                    // push return type
                    typename1 = ((struct payload *)tempnode1->payload)->function_definition.type;
                    stack_push(&type_stack, typename1);
                    stack_push(&type_stack, new_type(T_EVENT));
                }
                break;
            case N_ARGUMENT_SEQUENCE:
                break;
            case N_EVENT_DEFINITION:
                free(stack_pop(&type_stack));
                stack_push(&type_stack, new_type(T_GENERIC_EVENT));
                break;
            case N_INITIALIZER_SEQUENCE:
                for (int i = 0; i < temp->childc - 1; i++) {
                    stack_pop(&type_stack);
                }
                break;
            case N_INITIALIZER:
                if (*((enum types *)stack_peek(type_stack)) != T_VECTOR) {
                    success = 0;
                }
                break;
            case N_VECTOR:
                op1 = stack_pop(&type_stack);
                if (*op1 != T_NUMBER) {
                    success = 0;
                } else {
                    stack_push(&type_stack, new_type(T_VECTOR));
                }
                free(op1);
                op1 = NULL;
                break;
            case N_COMPONENT_SEQUENCE:
                op1 = stack_pop(&type_stack);
                for (int i = 1; i < temp->childc; i++) {
                    if (*((enum types *)stack_pop(&type_stack)) != *op1) {
                        success = 0;
                        break;
                    }
                }
                if (success) {
                    stack_push(&type_stack, op1);
                }
                break;
            case N_EXPRESSION_SEQUENCE:
                break;
            case N_COMPARISON_EXPRESSION:
                if (payload->alternative != ALT_ADDITIVE_EXPRESSION) {
                    op2 = stack_pop(&type_stack);
                    op1 = stack_pop(&type_stack);
                    if (*op1 != T_VECTOR || *op2 != T_VECTOR) {
                        success = 0;
                    } else {
                        stack_push(&type_stack, new_type(T_BOOL));
                    }
                    free(op1);
                    op1 = NULL;
                    free(op2);
                    op2 = NULL;
                }
                break;
            case N_EXPRESSION:
                break;
            case N_ADDITIVE_EXPRESSION:
                break;
            case N_ADDITION:
                op2 = stack_pop(&type_stack);
                op1 = stack_peek(type_stack);
                if (*op1 != T_NUMBER || *op2 != T_NUMBER) {
                    success = 0;
                }
                free(op2);
                op2 = NULL;
                break;
            case N_MULTIPLICATIVE_EXPRESSION:
                break;
            case N_MULTIPLICATION:
                op2 = stack_pop(&type_stack);
                op1 = stack_peek(type_stack);
                // TODO scalar * vector
                if (*op1 != T_NUMBER || *op2 != T_NUMBER) {
                    success = 0;
                }
                free(op2);
                op2 = NULL;
                break;
            case N_NEGATION:
                if (payload->alternative == ALT_NEGATION) {
                    if (*((enum types *)(stack_peek(type_stack))) != T_NUMBER) {
                        success = 0;
                    }
                }
                break;
            case N_PRIMARY_EXPRESSION:
                break;
            case N_ATOMIC:
                switch (payload->alternative) {
                    case ALT_IDENTIFIER:
                        ;
                        struct payload *ref = (struct payload *)(payload->atomic.ref->payload);
                        if (ref->type == N_PARAMETER) {
                            if (payload->atomic.identifier[1]) {
                                stack_push(&type_stack, new_type(T_VECTOR));
                            } else {
                                typename1 = strdup(ref->parameter.type);
                                stack_push(&type_stack, typename1);
                                stack_push(&type_stack, new_type(T_EVENT));
                            }
                        } else {
                            success = 0;
                        }
                        break;
                    case ALT_NUMBER:
                        stack_push(&type_stack, new_type(T_NUMBER));
                        break;
                    case ALT_VECTOR:
                        // Should be ok
                        break;
                    case ALT_EVENT_DEFINITION:
                        // Should be ok
                        break;
                    case ALT_FUNCTION_CALL:
                        // Should be ok
                        break;
                    default:
                        success = 0;
                        break;
                }
                break;
        }

        if (!success) {
            break;
        }
    }

    stack_free(&type_stack, free);
    tree_iterator_free(it);

    return success;
}
