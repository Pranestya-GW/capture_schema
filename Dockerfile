# Use an official Ubuntu as a parent image
FROM ubuntu:latest

# Update package list and install dependencies
RUN apt-get update && apt-get install -y \
    default-jre \
    graphviz

# Set a working directory
WORKDIR /app

# Set an entrypoint (optional)
ENTRYPOINT ["bash"]
