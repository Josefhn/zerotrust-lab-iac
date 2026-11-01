.PHONY: pki up test down deploy

pki:
	./scripts/pki.sh certs

up: pki
	docker compose up -d --wait

test:
	./tests/smoke.sh

down:
	docker compose down -v

deploy:
	ansible-playbook ansible/site.yml
