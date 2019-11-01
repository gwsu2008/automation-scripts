#!/bin/bash +x
info() {
   echo -e "\033[34m[INFO]\033[0m $1"
}

error() {
   echo -e "\033[31m[ERROR] $1\033[0m"
}

success() {
   echo -e "\033[32m[SUCCESS]\033[0m $1"
} 

warn() {
   echo -e "\033[33m[WARN]\033[0m $1"
}
 
info "This is information message"
error "Houston we have a problem"
success "Great!!!"
warn "Please check this warning."
echo "Foreground colors"
echo -e "\033[31m Red \033[0m"
echo -e "\033[32m Green \033[0m"
echo -e "\033[33m Yellow \033[0m"
echo -e "\033[34m Blue \033[0m"
echo -e "\033[35m Magneta \033[0m"
echo -e "\033[36m Cyan \033[0m"
echo "Background colors"
echo -e "\033[41m Red \033[0m"
echo -e "\033[42m Green \033[0m"
echo -e "\033[43m Yellow \033[0m"
echo -e "\033[44m Blue \033[0m"
echo -e "\033[45m Magneta \033[0m"
echo -e "\033[46m Cyan \033[0m"
echo "Different combinations"
echo -e "\033[1;31m Red \033[0m"
echo -e "\033[1;4;37;42m Green \033[0m"
echo -e "\033[1;43m Yellow \033[0m"
set -x
