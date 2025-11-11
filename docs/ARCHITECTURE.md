The Architecture of this project is 2 - D architecture where we are crerating a docker image and launching it in VM containing python 3.11 base image and a function to fetch the request and store it in postgress SQL.

It will have a put/get/post/push request we validate it and store iyt in the db. Our architecture is using loggers to handle the logging and the stage of application, which help in troubleshooting the overall issue aries in the environment.

This document outlines the architectural design of the Data Collection Service (DCS), a new microservice component within the SaaS compliance automation platform. It details the high-level, low-level, and deployment architectures, focusing on its specific requirement for on-premises deployment within client environments


Goals:
Secure Data Collection: Reliably and securely collect data from diverse client on-premises sources (databases, APIs, file systems).
On-Premises Deployment: Designed for deployment on client-managed virtualization infrastructure (VMware, Hyper-V)
Scalability (Local): Able to handle varying data volumes and job frequencies within the client environment.
Security & Compliance: High emphasis on data protection, access control, auditing, and vulnerability management.

HLD -
![unnamed](https://github.com/user-attachments/assets/83016ab7-8a6d-471a-9cb4-8491d100ca81)
