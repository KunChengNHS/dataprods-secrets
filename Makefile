# Makefile for Dataproducts secrets management utility
#
#

env ?= live
cls ?= yes
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
	@./secretsworker.sh decrypt $(topic) $(env) $(cls)

add-secret:
	$(call check_defined, topic secret)
	@./secretsworker.sh encrypt $(topic) $(env) $(cls) $(secret) $(comment)

update-secret:
	$(call check_defined, topic secret)
	@./secretsworker.sh update $(topic) $(env) $(cls) $(secret) $(comment)

list-topics:
	@./secretsworker.sh list-topics list-topics $(env) $(cls)

encrypt-file:
	$(call check_defined, topic)
	@./secretsworker.sh encrypt-file $(topic) $(env) $(cls)

decrypt-file:
	$(call check_defined, topic) $(cls)
	@./secretsworker.sh decrypt-file $(topic) $(env)
