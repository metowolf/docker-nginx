FROM alpine:edge as builder

LABEL maintainer="metowolf <i@i-meto.com>"

ARG NGINX_VERSION=1.17.2
ARG OPENSSL_VERSION=1.1.1c

RUN GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
	&& CONFIG="\
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--modules-path=/usr/lib/nginx/modules \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--pid-path=/var/run/nginx.pid \
		--lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
		--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
		--user=nginx \
		--group=nginx \
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_random_index_module \
		--with-http_secure_link_module \
		--with-http_stub_status_module \
		--with-http_auth_request_module \
		--with-http_xslt_module=dynamic \
		--with-http_image_filter_module=dynamic \
		--with-http_geoip_module=dynamic \
		--with-threads \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
		--with-stream_geoip_module=dynamic \
		--with-http_slice_module \
		--with-mail \
		--with-mail_ssl_module \
		--with-compat \
		--with-file-aio \
		--with-http_v2_module \
	" \
	&& addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& apk add --no-cache \
		gcc \
		libc-dev \
		make \
		openssl-dev \
		pcre-dev \
		zlib-dev \
		linux-headers \
		curl \
		gnupg \
		libxslt-dev \
		gd-dev \
		geoip-dev \
		git \
		gettext \
	&& curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
	&& curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc -o nginx.tar.gz.asc \
	&& export GNUPGHOME="$(mktemp -d)"; \
	for key in $GPG_KEYS; do \
    gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
  done \
  && gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
	&& mkdir -p /usr/src \
	&& tar -zxC /usr/src -f nginx.tar.gz \
	&& rm nginx.tar.gz \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	\
	# Brotli
	&& git clone https://github.com/eustas/ngx_brotli.git --depth=1 \
	&& (cd ngx_brotli; git submodule update --init) \
	\
	# cf-zlib
	&& git clone https://github.com/cloudflare/zlib.git --depth 1 \
	&& (cd zlib; make -f Makefile.in distclean) \
	\
	# OpenSSL
	&& curl -fSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o openssl-${OPENSSL_VERSION}.tar.gz \
	&& tar -xzf openssl-${OPENSSL_VERSION}.tar.gz \
	\
	# Sticky
	&& mkdir nginx-sticky-module-ng \
	&& curl -fSL https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng/get/master.tar.gz -o nginx-sticky-module-ng.tar.gz \
	&& tar -zxC nginx-sticky-module-ng -f nginx-sticky-module-ng.tar.gz --strip 1 \
	\
	# headers-more-nginx
	&& git clone https://github.com/openresty/headers-more-nginx-module.git --depth 1 \
	\
	&& CONFIG="$CONFIG \
		 --with-zlib=/usr/src/nginx-${NGINX_VERSION}/zlib \
		 --add-dynamic-module=/usr/src/nginx-${NGINX_VERSION}/ngx_brotli \
		 --add-dynamic-module=/usr/src/nginx-${NGINX_VERSION}/nginx-sticky-module-ng \
		 --add-dynamic-module=/usr/src/nginx-${NGINX_VERSION}/headers-more-nginx-module \
 	 	 --with-openssl=/usr/src/nginx-${NGINX_VERSION}/openssl-${OPENSSL_VERSION} \
	" \
	&& ./configure $CONFIG \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& install -m644 html/index.html /usr/share/nginx/html/ \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	&& nginx -V

COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx.vh.default.conf /etc/nginx/conf.d/default.conf
COPY config/logrotate /etc/nginx/logrotate


FROM alpine:3.10

COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /usr/bin/envsubst /usr/local/bin/envsubst
COPY --from=builder /usr/lib/nginx/ /usr/lib/nginx/
COPY --from=builder /usr/share/nginx /usr/share/nginx

RUN apk add --no-cache \
		musl \
		pcre \
		libssl1.1 \
		libcrypto1.1 \
		zlib \
		libintl \
		tzdata \
		logrotate \
	&& sed -i -e 's:/var/log/messages {}:# /var/log/messages {}:' /etc/logrotate.conf \
	&& echo '1 0 * * * /usr/sbin/logrotate /etc/logrotate.conf -f' > /var/spool/cron/crontabs/root \
	&& addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& mkdir -p /var/log/nginx \
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
	&& mv /etc/nginx/logrotate /etc/logrotate.d/nginx \
	&& chmod 755 /etc/logrotate.d/nginx

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80 443
STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
