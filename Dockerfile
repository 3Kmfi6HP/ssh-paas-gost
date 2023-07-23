# Select base image
FROM debian

# Update system packages
RUN apt-get update -y && apt-get upgrade -y

# Install necessary packages
RUN apt-get install -y wget unzip sudo openssh-server curl nano python3 vim iproute2 coreutils bash

# Setup environment variables
ENV SERVER_PORT=7860 \
    SSH_PUB_KEY='ssh-rsa xxx'

# Create new user with uid 1000
RUN useradd -m -u 1000 customuser

# Download, extract, chmod and clean gost
RUN wget -t 2 -T 10 -N https://github.com/go-gost/gost/releases/download/v3.0.0-rc8/gost_3.0.0-rc8_linux_amd64v3.tar.gz && \
    tar -xzvf gost_3.0.0-rc8_linux_amd64v3.tar.gz && \
    chmod +x gost && \
    rm -f gost_3.0.0-rc8_linux_amd64v3.tar.gz
    
# Change to customuser
USER customuser

# Create customuser home directory
RUN echo "${HOME}/custom_ssh/sshd_config" && mkdir ${HOME}/custom_ssh && mkdir ${HOME}/.ssh

# Create sshd_script.sh here
RUN echo "#!/bin/sh\n\
if [ -n \"$SERVER_PORT\" ]; then\n\
    # generate sshd_config file for custom sshd\n\
    cat >${HOME}/custom_ssh/sshd_config <<EOF\n\
Port 2222\n\
HostKey ${HOME}/custom_ssh/ssh_host_rsa_key\n\
HostKey ${HOME}/custom_ssh/ssh_host_dsa_key\n\
AuthorizedKeysFile  ${HOME}/.ssh/authorized_keys\n\
PasswordAuthentication no\n\
#PermitEmptyPasswords yes\n\
PermitRootLogin yes\n\
PubkeyAuthentication yes\n\
## Enable DEBUG log.\n\
LogLevel DEBUG\n\
ChallengeResponseAuthentication no\n\
# UsePAM no\n\
X11Forwarding yes\n\
PrintMotd no\n\
AcceptEnv LANG LC_*\n\
Subsystem   sftp    /usr/lib/ssh/sftp-server\n\
PidFile ${HOME}/custom_ssh/sshd.pid\n\
EOF\n\
    # generate ssh host keys\n\
    ssh-keygen -f ${HOME}/custom_ssh/ssh_host_rsa_key -N '' -t rsa\n\
    ssh-keygen -f ${HOME}/custom_ssh/ssh_host_dsa_key -N '' -t dsa\n\
    # extract public key from SSH_PUB_KEY and add to authorized_keys\n\
    echo \"${SSH_PUB_KEY}\" >>${HOME}/.ssh/authorized_keys\n\
    cat ${HOME}/custom_ssh/ssh_host_rsa_key.pub >>${HOME}/.ssh/authorized_keys\n\
    cat ${HOME}/custom_ssh/ssh_host_dsa_key.pub >>${HOME}/.ssh/authorized_keys\n\
    # set permissions for SSH\n\
    chmod 600 ${HOME}/.ssh/authorized_keys\n\
    chmod 700 ${HOME}/.ssh\n\
    chmod 600 ${HOME}/custom_ssh/*\n\
    chmod 644 ${HOME}/custom_ssh/sshd_config\n\
    # start sshd in background\n\
    # echo -e "start sshd" && /usr/sbin/sshd -f ${HOME}/custom_ssh/sshd_config -D &\n\
fi" > /home/customuser/sshd_script.sh \
&& chmod +x /home/customuser/sshd_script.sh

RUN bash /home/customuser/sshd_script.sh
# Expose server port
EXPOSE ${SERVER_PORT}

# Start gost and sshd server
CMD ["bash", "-c", "./gost -L mws://user:pass@:${SERVER_PORT}?path=/ws & /usr/sbin/sshd -f ${HOME}/custom_ssh/sshd_config -D & tail -f /dev/null"]
