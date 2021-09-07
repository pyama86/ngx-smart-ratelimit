# nginx-smart-ratelimit

It is belong to [ngx_mruby](https://github.com/matsumotory/ngx_mruby).

## Usage
please see [test.conf](./conf.d/test.conf)

blog: TBD

## development
You can use docker-compose.
```
$ docker-compose up
$ curl -b 'slimiter=dummy;' http://127.0.0.1:9090 -i
```
