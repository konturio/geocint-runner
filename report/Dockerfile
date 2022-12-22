FROM node:lts-alpine
ENV NODE_ENV=production
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install -g npm@latest
RUN npm install
COPY . .
EXPOSE 5000
CMD ["node", "app.js"]