# Makefile for Dataproducts secrets management utility
#
#

env ?= live
default:
	@./secretsworker.sh usage

check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))

show-secret: 
	$(call check_defined, topic)
	@./secretsworker.sh decrypt $(topic) $(env)

add-secret:
	$(call check_defined, topic secret)
	@./secretsworker.sh encrypt $(topic) $(env) $(secret) $(comment)

update-secret:
	$(call check_defined, topic secret)
	@./secretsworker.sh update $(topic) $(env) $(secret) $(comment)

list-topics:
	@./secretsworker.sh list-topics list-topics $(env)

encrypt-file:
	$(call check_defined, topic)
	@./secretsworker.sh encrypt-file $(topic) $(env)

decrypt-file:
	$(call check_defined, topic)
	@./secretsworker.sh decrypt-file $(topic) $(env)
