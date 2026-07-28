FROM node:24-alpine

WORKDIR /app

RUN rm -rf /usr/local/lib/node_modules/npm \
  && rm -f /usr/local/bin/npm /usr/local/bin/npx

COPY server.js index.html ./

EXPOSE 3000

CMD ["node", "server.js"]
