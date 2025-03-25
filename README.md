# postgresql-maximalism

A repository dedicated to using PostgreSQL for everything.

```bash
cd postgresql-maximalism/
docker compose up -d
```

```bash
sudo curl -o /usr/share/keyrings/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc

sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

sudo apt install -y postgresql-client-16
```
