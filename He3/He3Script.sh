#!/bin/sh

#  He3Script.sh
#  He3
#
#  Created by Carlos D. Santiago on 12/29/20.
#  Copyright © 2020-2021 Carlos D. Santiago. All rights reserved.

# Localize our files with BartyCroouch: https://github.com/Flinesoft/BartyCrouch
if which bartycrouch > /dev/null; then
    bartycrouch update -x
    
    bartycrouch lint -x
else
    echo "warning: BartyCrouch not installed, download it from https://github.com/Flinesoft/BartyCrouch"
fi
