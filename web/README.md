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

As imagens em `assets/images/` incluem versões otimizadas para web de referências visuais do repositório e novos visuais complementares gerados para a landing page. O vídeo em `assets/video/combat-preview.mp4` é uma versão comprimida do recorte existente, com poster separado. O áudio em `assets/audio/battle-theme.mp3` é uma cópia do material de combate já catalogado no projeto.

## Personalização rápida

Para trocar o destino do CTA principal, edite os links no `index.html`. Para substituir a trilha, troque `assets/audio/battle-theme.mp3` e mantenha o mesmo caminho ou ajuste o elemento `<audio>`. Para adicionar canais oficiais, substitua o botão “Avisar quando estiver pronto” por links reais e remova o estado de placeholder no `script.js`.

## Acessibilidade e performance

O site não inicia áudio automaticamente, possui controles nativos para vídeo, usa `alt` text, foco visível, modal de mídia navegável por teclado e reduz animações quando `prefers-reduced-motion` está ativo. Imagens e vídeo foram redimensionados/comprimidos para a página, e a maior parte das imagens secundárias usa `loading="lazy"`.
