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

O vídeo `assets/video/anime-verse-trailer-animated.mp4` é o trailer atual, com 33,4 segundos (1002 quadros a 30 fps), montado por `scripts/build_trailer.py` — nenhum corte é feito à mão. Os cortes caem na grade de compasso da trilha (129,35 BPM) e a montagem tem três origens declaradas: **gameplay real** gravado no Roblox Studio (`2026-08-13 14-26-49.mp4`, recortado do viewport e identificado na tela com a etiqueta “GAMEPLAY REAL · ROBLOX STUDIO”), **planos animados de combate** vindos do trailer anterior (preservado em `media/trailer-combat-animated-source.mp4`, fora do site, só como fonte de montagem) e os clipes de VFX `assets/video/trailer-domain-expansion-vfx.mp4` e `assets/video/trailer-violet-pulse-vfx.mp4`. As cartelas de texto são desenhadas por código com Pillow. O poster correspondente é `assets/images/anime-verse-trailer-animated-poster.jpg`, extraído de um quadro do próprio trailer. A trilha principal do site é `assets/audio/jackpot.mp3`, convertida e normalizada a partir do arquivo enviado para esta atualização.

Os streams de vídeo e de áudio do trailer têm a mesma duração — a versão anterior tinha 28,46 s de vídeo dentro de um container de 35 s, o que congelava o último quadro por ~6,5 s enquanto a música continuava. `python3 scripts/build_trailer.py --check` reprova o arquivo se as durações voltarem a divergir mais de 0,1 s.

## Personalização rápida

Para trocar o destino do CTA principal, edite os links no `index.html`. Para substituir a trilha, troque `assets/audio/jackpot.mp3` e mantenha o mesmo caminho ou ajuste o elemento `<audio>`. Para mexer no trailer, edite a EDL no topo de `scripts/build_trailer.py` e rode `python3 scripts/build_trailer.py` (regera vídeo e poster); se a duração mudar, ajuste o rótulo `play / 00:33` no `index.html`. Para adicionar canais oficiais, substitua o botão “Avisar quando estiver pronto” por links reais e remova o estado de placeholder no `script.js`.

## Acessibilidade e performance

O site não inicia áudio automaticamente, possui controles nativos para vídeo, usa `alt` text, foco visível, modal de mídia navegável por teclado e reduz animações quando `prefers-reduced-motion` está ativo. Imagens e vídeo foram redimensionados/comprimidos para a página, e a maior parte das imagens secundárias usa `loading="lazy"`.
