package main

import (
	"fmt"
	"log"
	"net/http"
	"net/http/cookiejar"
	"strconv"
	"sync"
	"sync/atomic"
	"time"
)

var requestURL = "http://127.0.0.1:9090/"
var concurrency = 10
var accessNumber = 10000

func main() {
	wg := &sync.WaitGroup{}
	var ok uint64
	var ng uint64
	for i := 0; i < concurrency; i++ {
		i := i
		wg.Add(1)
		go func() {
			defer wg.Done()
			jar, err := cookiejar.New(nil)
			if err != nil {
				log.Fatal(err)
			}
			client := &http.Client{Jar: jar, Timeout: 3 * time.Second}
			res, err := client.Get(requestURL)
			if err != nil {
				log.Fatal(err)
			}
			res.Body.Close()
			res = nil

			for n := 0; n < accessNumber/concurrency; n++ {
				req, _ := http.NewRequest("GET", requestURL, nil)
				req.Header.Set("CLIENT-NUM", strconv.Itoa(i))
				res, err = client.Do(req)
				if err != nil {
					atomic.AddUint64(&ng, 1)
					continue
				} else {
					res.Body.Close()
					if res.StatusCode != 200 {
						atomic.AddUint64(&ng, 1)
					} else {
						atomic.AddUint64(&ok, 1)
					}
				}
				current := atomic.LoadUint64(&ok) + atomic.LoadUint64(&ng)
				if current%1000 == 0 {
					fmt.Printf("current count :%d\n", current)
				}
				res = nil
			}
		}()
	}
	wg.Wait()
	fmt.Printf("ok:%d,  ng:%d", ok, ng)
}
