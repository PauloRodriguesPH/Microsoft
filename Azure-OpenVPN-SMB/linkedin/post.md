# Post do LinkedIn

Troque `[LINK DO GITHUB]` pelo link do repositório antes de publicar.

---

Há 2 meses compartilhei aqui a migração dos arquivos de uma pequena empresa (cerca de 20 usuários e 500 GB) para a nuvem. De lá pra cá, a evolução continuou, com algumas dificuldades e ajustes no caminho.

Uma delas: a porta 445 (SMB). Alguns provedores de internet bloqueiam essa porta, e quem trabalha de casa simplesmente não consegue acessar os arquivos no Azure Files.

A saída "padrão" seria o Azure VPN Gateway, mas ele custa cerca de US$ 140/mês só pelo gateway (valor de referência). Pesado demais para uma empresa desse porte.

Então montei um servidor OpenVPN em uma VM pequena na própria Azure (algo em torno de US$ 30 a 35/mês). Alguns detalhes que fizeram diferença:

🔹 A VPN é só um desvio: quem não tem bloqueio acessa direto. Pela VPN passa apenas o tráfego do storage (split tunnel)
🔹 O firewall da VM encaminha somente TCP 445 para o IP do storage, e o NSG da Azure bloqueia o resto da saída. Ela não vira um relay
🔹 Alertas de tráfego e orçamento, para não ter surpresa na fatura

Para esse porte, atende bem. Documentei tudo no GitHub (anonimizado): passo a passo, custos, scripts e os erros que encontrei pelo caminho.

👉 [LINK DO GITHUB]

Já passou por esse bloqueio da 445? Como resolveu?

#Azure #AzureFiles #OpenVPN #Infraestrutura #CloudComputing #Redes #TI #SMB #Modernização
