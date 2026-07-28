FROM node:24-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY server.js index.html ./

FROM node:24-alpine

WORKDIR /app

RUN rm -rf /usr/local/lib/node_modules/npm \
  && rm -f /usr/local/bin/npm /usr/local/bin/npx

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/server.js ./server.js
COPY --from=build /app/index.html ./index.html

EXPOSE 3000

CMD ["node", "server.js"]
