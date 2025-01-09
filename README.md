# Symfony 7 and Valkey issues

`symfony/lock` works perfectly fine with Redis and Valkey up to version 6.4.
After that instead of using `eval`, it uses `evalSha`.

For Redis it's still fine, but not for Valkey.

## How to run it

Make sure you have `git`, `docker` and `docker compose` installed and up to date.
Then it should work like:

```shell
git clone git@github.com:PatNowak/symfony-valkey-poc.git
cd symfony-valkey-poc

# to run valkey (by default we should have here symfony/lock 7.2)
./app.sh valkey
```