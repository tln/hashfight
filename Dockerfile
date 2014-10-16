FROM node:0.10
EXPOSE  8080

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

ADD . /usr/src/app/
RUN npm install

CMD [ "npm", "start" ]