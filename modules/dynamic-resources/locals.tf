locals {
  # Shared description templates to avoid repeating long strings across parameter blocks
  desc = {
    container_name  = <<-DESC
      Alphanumeric characters, hyphens, and underscores only (max 63 chars). Leave empty to skip this container. This name is used as the container hostname and network alias.

      Example: `redis`, `postgres`, or `my-service`
    DESC
    container_image = <<-DESC
      Docker image (e.g., 'redis:latest', 'postgres:13', 'mysql:8'). Format: `<repository>/<image>:<tag>` or `<image>:<tag>` or `<image>`.

      Example: `postgres:15-alpine`
    DESC
    container_port  = <<-DESC
      The actual port the container listens on (1-65535). This is the container's internal port that will be proxied.

      Example: `80`, `8080`, `3306`
    DESC
    local_port      = <<-DESC
      The local proxy port (19000-20000) to use for accessing this container. This must be unique across all containers and apps. The Coder app will proxy this local port to the container's port.

      Example: `19080`, `19081`, `19306`
    DESC
    volume_mounts   = <<-DESC
      Select one or more volume mounts in the form 'volume-name:/path/in/container'. The volume name must match an entry from 'Additional Volumes' or a preset volume. Use the tag selector to add multiple mounts.

      Example: `postgres-data:/var/lib/postgresql/data` or `uploads:/srv/uploads`
    DESC
    env_vars        = <<-DESC
      One environment variable per line, in KEY=VALUE format. Use valid env var names (letters, numbers, underscore) on the left side.

      Example:
        ```
        POSTGRES_USER=embold

        POSTGRES_PASSWORD=embold
        ```
    DESC
    app_slug        = <<-DESC
      URL-safe identifier (lowercase, hyphens, underscores). Slug must be lowercase and up to 32 chars.

      Example: `redis-cli`
    DESC
    app_url         = <<-DESC
      Internal service URL reachable from the workspace. Include protocol and optional port. Used to generate a reverse-proxy mapping.

      Example: `http://redis:6379` or `http://localhost:9000/path`
    DESC
    app_icon        = <<-DESC
      Icon path or emoji code for the app.

      Example: `/icon/redis.svg` or `/emojis/1f310.png`
    DESC
  }
  icon = {
    docker           = "/icon/docker.svg"
    environment      = "https://api.embold.net/icons/?name=environment.svg&color=009dff"
    folder           = "/icon/folder.svg"
    globe            = "https://api.embold.net/icons/?name=fas-globe.svg&color=009dff"
    mongo            = "https://api.embold.net/icons/?name=mongodb.svg"
    mysql            = "https://api.embold.net/icons/?name=mysql.svg"
    nametag          = "https://api.embold.net/icons/?name=title.svg&color=009dff"
    paperclip        = "https://api.embold.net/icons/?name=fas-link.svg&color=009dff"
    postgres         = "/icons/postgres.svg"
    quantity         = "https://api.embold.net/icons/?name=quantity.svg&color=009dff"
    redis            = "https://api.embold.net/icons/?name=redis.svg"
    share_permission = "https://api.embold.net/icons/?name=fas-user-gear.svg&color=009dff"
    socket           = "https://api.embold.net/icons/?name=fas-plug.svg&color=009dff"
    tag              = "https://api.embold.net/icons/?name=fas-tag.svg&color=009dff"
  }
}
