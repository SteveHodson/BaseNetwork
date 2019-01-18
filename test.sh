#!/bin/sh

#------------------------------------------------------------------------------
# Validation for all templates in current and all subdirectories.  It will 
# process *.yaml files only and uses the `validate-template` function that
# comes with AWSCLI.
#
# Author: Steve Hodson 
# Date: Jan 2019
# 
# Requires AWSCLI
#
# Usage: ./test.sh
#
#------------------------------------------------------------------------------
echo "Validating the templates"

error_count=0
for template in $(find . -name '*.yaml'); 
do
    error=$(aws cloudformation validate-template --template-body file://$template 2>&1 >/dev/null); 
    if [ "$?" -gt "0" ]; then 
        ((error_count++));
        echo "\e[1;31m[fail]\e[0m $template: $error";
    else 
        echo "\e[1;32m[pass]\e[0m $template";
    fi;
done

if [ "$error_count" -gt 0 ]; then
    echo "\e[1;31m$error_count template validation error(s)\e[0m";
    exit 1; 
else 
    echo "\e[1;32mAll templates have been validated\e[0m";
fi;