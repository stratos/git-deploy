FROM debian:jessie

RUN sed -i "s/httpredir.debian/deb.debian/g" /etc/apt/sources.list && \
    apt-get clean && \
    apt-get update && \
    apt-get install -y --force-yes \
        wget \
        vim \
        nano \
        ssh \
        python-pip \
        telnet \
        apt-transport-https \
        ca-certificates \
        git &&\
    apt-key adv \
        --keyserver hkp://pgp.mit.edu:80 \
        --recv-keys 58118E89F3A912897C070ADBF76221572C52609D && \
    echo "deb https://apt.dockerproject.org/repo debian-jessie main" >> \
        /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --force-yes docker-engine && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    pip install docker-compose

RUN echo "source /test/test_helper.bash" >> /root/.bashrc

RUN git clone https://github.com/sstephenson/bats.git && \
    bash bats/install.sh /usr

ADD test-keys/test-sshkey /root/.ssh/id_rsa
RUN chmod 400 /root/.ssh/id_rsa
ADD ssh_client.config /root/.ssh/config
RUN git config --global user.email "you@example.com" && \
    git config --global user.name "Your Name"

WORKDIR /test
