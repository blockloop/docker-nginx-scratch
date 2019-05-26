FROM  alpine:latest as build

#Define build argument for version
ARG VERSION=1.16.0

# Install build tools, libraries and utilities 
RUN apk add --no-cache --virtual .build-deps                                        \
        build-base                                                                  \
        gnupg                                                                       \
        pcre-dev                                                                    \
        openssl                                                                     \
        openssl-dev                                                                 \
        wget                                                                        \
        zlib-dev

# Retrieve, verify and unpack Nginx source - key server pgp.mit.edu  
RUN set -x                                                                      &&  \
    mkdir -p /tmp/nginx                                                         &&  \
    cd /tmp                                                                     &&  \
    gpg --keyserver pool.sks-keyservers.net --recv-keys                             \
        B0F4253373F8F6F510D42178520A9993A1C052F8                                &&  \
    wget -q http://nginx.org/download/nginx-${VERSION}.tar.gz                   &&  \
    wget -q http://nginx.org/download/nginx-${VERSION}.tar.gz.asc               &&  \
    gpg --verify nginx-${VERSION}.tar.gz.asc                                    &&  \
    tar -xf nginx-${VERSION}.tar.gz -C nginx --strip-components=1               &&  \
    echo ${VERSION}                                           

WORKDIR /tmp/nginx

# Build and install nginx
RUN ./configure                                                                     \
        --with-ld-opt="-static"                                                     \
        --with-http_sub_module                                                      \
        --with-http_ssl_module                                                  &&  \
    make install                                                                &&  \
    strip /usr/local/nginx/sbin/nginx

# Symlink access and error logs to /dev/stdout and /dev/stderr, in 
# order to make use of Docker's logging mechanism
RUN ln -sf /dev/stdout /usr/local/nginx/logs/access.log                         &&  \
    ln -sf /dev/stderr /usr/local/nginx/logs/error.log

FROM scratch
# Customise static content, and configuration
COPY --from=build /etc/passwd /etc/group /etc/
COPY --from=build /usr/local/nginx /usr/local/nginx
COPY --from=build /tmp/nginx/conf/mime.types /etc/nginx/mime.types
COPY index.html /usr/share/nginx/html/
COPY nginx.conf /usr/local/nginx/conf/

#Change default stop signal from SIGTERM to SIGQUIT
STOPSIGNAL SIGQUIT

# Expose port
EXPOSE 80

# Define entrypoint and default parameters 
ENTRYPOINT ["/usr/local/nginx/sbin/nginx"]
CMD ["-g", "daemon off;"]
