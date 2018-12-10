FROM mcr.microsoft.com/powershell
RUN apt-get update && apt-get install -y apt-transport-https curl lsb-release software-properties-common gnupg2; rm -rf /var/lib/apt/lists/*
RUN curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list
RUN AZ_REPO=$(lsb_release -cs); echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list
RUN apt-key --keyring /etc/apt/trusted.gpg.d/Microsoft.gpg adv --keyserver packages.microsoft.com --recv-keys BC528686B50D79E339D3721CEB3E94ADBE1229CF
RUN apt-get update; apt-get install -y kubectl azure-cli; rm -rf /var/lib/apt/lists/*
RUN echo '#!/bin/bash\nkubectl config set-cluster default --server=https://kubernetes.default --certificate-authority=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt; kubectl config set-context default --cluster=default; token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token); kubectl config set-credentials user --token=$token; kubectl config set-context default --user=user; kubectl config use-context default' > /opt/configure-kubectl.sh
RUN chmod +x /opt/configure-kubectl.sh
ADD retry.ps1 /opt/retry.ps1
CMD [ "pwsh" ]