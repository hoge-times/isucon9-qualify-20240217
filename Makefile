export GO111MODULE=on

all: bin/benchmarker bin/benchmark-worker bin/payment bin/shipment

bin/benchmarker: cmd/bench/main.go bench/**/*.go
	go build -o bin/benchmarker cmd/bench/main.go

bin/benchmark-worker: cmd/bench-worker/main.go
	go build -o bin/benchmark-worker cmd/bench-worker/main.go

bin/payment: cmd/payment/main.go bench/server/*.go
	go build -o bin/payment cmd/payment/main.go

bin/shipment: cmd/shipment/main.go bench/server/*.go
	go build -o bin/shipment cmd/shipment/main.go

vet:
	go vet ./...

errcheck:
	errcheck ./...

staticcheck:
	staticcheck -checks="all,-ST1000" ./...

clean:
	rm -rf bin/*


# ここから俺等
.PHONY: bn
bn:
	make re
	./bin/benchmarker -target-url http://localhost

# アプリ､nginx､mysqlの再起動
.PHONY: re
re:
	make nrestart
	make mrestart

# アプリの再起動
.PHONY: arestart
arestart:
	cd golang && make all
	sudo systemctl restart isu-go.service
	sudo systemctl status isu-go.service

# nginxの再起動
.PHONY: nrestart
nrestart:
	sudo rm /var/log/nginx/access.log
	sudo systemctl reload nginx
	sudo systemctl status nginx

# mysqlの再起動
.PHONY: mrestart
mrestart:
	sudo rm /var/log/mysql/slow.log
	sudo mysqladmin flush-logs
	sudo systemctl restart mysql
	sudo systemctl status mysql
	echo "set global slow_query_log = 1;" | sudo mysql
	echo "set global slow_query_log_file = '/var/log/mysql/slow.log';" | sudo mysql
	echo "set global long_query_time = 0;" | sudo mysql

# アプリのログを見る
.PHONY: nalp
nalp:
	sudo cat /var/log/nginx/access.log | alp ltsv -m "/items/\d+.json","/users/\d+.json","/upload/[\w\d]+.jpg","/transactions/\d+.png","/new_items/\d+.json" --sort=sum --reverse --filters 'Time > TimeAgo("10m")'

# mysqlのslowlogを見る
.PHONY: pt
pt:
	sudo pt-query-digest /var/log/mysql/slow.log

.PHONY: log
log:
	journalctl -xe | grep  app.go