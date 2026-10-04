# JupyterLab server configuration
# Copied into /opt/conda/etc/jupyter/jupyter_lab_config.py at build time.
# These settings are required for JupyterLab to work correctly inside
# a container accessed via SSH tunnel.
# noqa: F821 - 'c' is injected by Jupyter at runtime

c.ServerApp.ip = '0.0.0.0'           # listen on all interfaces
c.ServerApp.port = 8888               # match EXPOSE in Dockerfile
c.ServerApp.open_browser = False      # no browser inside container
c.ServerApp.allow_root = False        # micromamba image runs as $MAMBA_USER
c.ServerApp.root_dir = '/home/jovyan/work'  # default notebook directory

# Security
# Token authentication is enabled by default in JupyterLab -- do not disable.
# The token is printed to the Slurm log on startup and used to access
# JupyterLab via the SSH tunnel.
c.ServerApp.token = ''                # empty = auto-generate token at runtime
c.ServerApp.password = ''             # disable password auth, use token only
