# helloworldfull
A Hello World app with end to end flow

## Run locally
npm start

Then open http://localhost:3000

## Build and run with Docker
Build:
docker build -t click-counter-app .

Run:
docker run -p 3000:3000 click-counter-app

## For AKS practice
Once the container runs locally, you can push it to a container registry and deploy it to AKS.
