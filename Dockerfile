FROM ubuntu

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  curl \
  nginx \
  siege \
  procps \
  && rm -rf /var/lib/apt/lists/*

# Generate the "Internet Mode" content
RUN echo "Standard Hello" > /var/www/html/index.html && \
    echo "Small metadata file" > /var/www/html/meta.txt && \
    head -c 1M </dev/urandom > /var/www/html/large.bin

# Create the URL file for Siege
RUN printf "http://localhost/\nhttp://localhost/meta.txt\nhttp://localhost/large.bin" > /etc/siege/urls.txt

COPY ./init.sh /data/init.sh
RUN chmod 777 /data/init.sh

CMD [ "/bin/bash", "-c", "/data/init.sh" ]