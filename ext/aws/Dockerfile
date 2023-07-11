
WORKDIR /usr/local

RUN curl -SsfLk "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscli-exe-linux-x86_64.zip
RUN unzip awscli-exe-linux-x86_64.zip
RUN ./aws/install --bin-dir /usr/local/aws/bin/

ENV PATH /usr/local/aws/bin:$PATH

