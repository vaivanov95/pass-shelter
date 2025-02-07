FROM ubuntu:22.04

# Set build-time variables for the user
ARG USER_ID
ARG GROUP_ID

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libargon2-dev \
    argon2 \
    gnupg2 \
    pass \
    oathtool \
    tree \
    zip \
    unzip && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user with specific UID/GID (matching the host user, if desired)
RUN groupadd -o -g ${GROUP_ID} user && \
    useradd -o -u ${USER_ID} -g ${GROUP_ID} -m user

# Copy scripts into the container
COPY scripts /usr/local/bin/


# Make scripts executable
RUN chmod +x /usr/local/bin/*

# Create necessary directories for the user
RUN mkdir -p /home/user/.gnupg /home/user/.password-store && \
    chown -R user:user /home/user/.gnupg /home/user/.password-store && \
    chmod 700 /home/user/.gnupg

# Switch to non-root user
USER user
WORKDIR /home/user


# No CMD or ENTRYPOINT here, so we can run different commands as needed
