#!/bin/bash
# Docker entrypoint script for Revive Adserver
# Handles Cloud Run HTTPS proxy detection

# Trust Cloud Run's X-Forwarded-* headers
# This prevents redirect loops when behind the load balancer
if [ ! -z "$K_SERVICE" ]; then
    echo "Running in Cloud Run environment"
    
    # Enable Apache proxy headers
    a2enmod remoteip 2>/dev/null || true
    
    # Create Apache config for proxy headers
    cat > /etc/apache2/conf-available/cloudrun-proxy.conf << 'EOF'
# Trust Cloud Run load balancer headers
RemoteIPHeader X-Forwarded-For

# Set HTTPS environment variable when behind proxy
SetEnvIf X-Forwarded-Proto "https" HTTPS=on
EOF
    
    a2enconf cloudrun-proxy 2>/dev/null || true
fi

# Execute the main command (Apache)
exec "$@"
