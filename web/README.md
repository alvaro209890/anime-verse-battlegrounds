# Anime Verse Battlegrounds — site de divulgação

Landing page estática do Anime Verse Battlegrounds. O site foi mantido dentro de `web/` para não interferir no projeto Roblox/Luau e pode ser publicado em qualquer hospedagem de arquivos estáticos, incluindo GitHub Pages.

## Abrir localmente

A página não depende de backend. Para evitar restrições de `file://` ao carregar vídeo e áudio, sirva a pasta com um servidor local simples:

```bash
cd web
python3 -m http.server 4173
```

Em seguida, abra `http://localhost:4173`.

## Publicar no GitHub Pages

Nas configurações do repositório, abra **Pages**, escolha a branch que contém o site e a pasta `/web` como origem quando essa opção estiver disponível. Alternativamente, copie o conteúdo de `web/` para uma branch de publicação dedicada e selecione essa branch no Pages. Como a página é estática, não há variáveis de ambiente ou banco de dados necessários.

## Conteúdo e honestidade de produto

O texto usa a documentação atual do projeto como fonte e separa o que está implementado/validado automaticamente do que ainda é roadmap. Os canais sociais e o link do jogo permanecem em estado de “em breve” até que os destinos oficiais sejam definidos.

O vídeo `assets/video/anime-verse-trailer-animated.mp4` é o trailer atual, com cerca de 35 segundos, baseado no trailer animado de referência e ampliado com cortes de vídeo, expansão de domínio, dois clipes de VFX em movimento, flashes de transição e a trilha Jackpot integrada; o poster correspondente é `assets/images/anime-verse-trailer-animated-poster.jpg`. Os clipes `assets/video/trailer-domain-expansion-vfx.mp4` e `assets/video/trailer-violet-pulse-vfx.mp4` são sequências de VFX animadas usadas na montagem. Nenhuma foto estática é usada no corpo do trailer, e o gameplay gravado pelo usuário não é usado pelo player atual. A trilha principal do site é `assets/audio/jackpot.mp3`, convertida e normalizada a partir do arquivo enviado para esta atualização.

## Personalização rápida

Para trocar o destino do CTA principal, edite os links no `index.html`. Para substituir a trilha, troque `assets/audio/jackpot.mp3` e mantenha o mesmo caminho ou ajuste o elemento `<audio>`. Para trocar o trailer, substitua `assets/video/anime-verse-trailer-animated.mp4` e o poster correspondente. Para adicionar canais oficiais, substitua o botão “Avisar quando estiver pronto” por links reais e remova o estado de placeholder no `script.js`.

## Acessibilidade e performance

O site não inicia áudio automaticamente, possui controles nativos para vídeo, usa `alt` text, foco visível, modal de mídia navegável por teclado e reduz animações quando `prefers-reduced-motion` está ativo. Imagens e vídeo foram redimensionados/comprimidos para a página, e a maior parte das imagens secundárias usa `loading="lazy"`.
