# Project Domain Example
This project is the template for the standard configuration of domains in Payara DevOps managed projects.

**DevOps Objective:** [Payara Confluence | Project Domain SOP](https://payara.atlassian.net/wiki/spaces/ITOPS/pages/3846766632/Project+Domain+SOP)

**Author**: James Hillyard

---

## Usage
This template uses placeholders which you should replace before using it. Specifically in nginx.conf and init-letsencrypt.sh.
After copying the contents of those two files into your local environment, ensure you replace `example.payara.fish` with your domain.

In nginx.conf you also must replace the placeholders in the line `proxy_pass http://[CONTAINER_NAME]:[CONTAINER_PORT];`. Replace [CONTAINER_NAME] with the name of the service you wish to forward to defined in your docker-compose.yml and replace [CONTAINER_PORT] with the port to access that container.