FROM ${baseImage} as builder

LABEL maintainer="hellotoy@yourmail.com"
RUN useradd -s /bin/bash app
WORKDIR /app/
ADD --chown=app:app target/${finalName}-toy.tar.gz ./${finalName}-toy
COPY --chown=app:app /entrypoint.sh ./
COPY --chown=app:app /app.def ./

RUN chmod -R a+x /app

USER app
ENTRYPOINT ["/usr/local/bin/tini", "-g", "--", "/app/entrypoint.sh"]
CMD ["start"]