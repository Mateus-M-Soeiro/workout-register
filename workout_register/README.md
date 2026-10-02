# Ritmo

Aplicação Flutter para organizar rotinas, registrar séries e acompanhar a evolução.

- **Rotinas:** criação e edição em modal, lista de exercícios e exclusão de rotinas.
- **Treino:** exercícios começam sem séries e podem permanecer assim ao concluir. Séries adicionadas exigem repetições e peso válidos e podem ser removidas. Aceita peso decimal com vírgula ou ponto e 0 kg para exercícios sem carga externa. Exibe as séries da última sessão da mesma rotina como referência e registra data/hora de início e fim.
- **Histórico:** acesso por rotina ou pelo ícone no topo do menu, com início, fim e valores individuais de cada série. Sessões antigas são preservadas, com início indicado como não registrado. O vínculo antigo por nome é recuperado quando há uma única rotina correspondente; registros ambíguos continuam no histórico geral.
- **Evolução:** gráficos diários de repetições ou volume (peso × repetições), períodos de 7/30 dias e histórico com detalhes das séries.

Rotinas, histórico e o treino em andamento são salvos localmente com `shared_preferences`. As alterações no treino são salvas a cada edição e ao entrar em background. Ao reabrir, use **Retomar treino**, mantendo o horário original de início. Voltar ao menu conserva o treino; **Descartar treino** remove o rascunho após confirmação. Ao concluir, o histórico e a remoção do rascunho são gravados juntos.

É possível marcar e desmarcar exercícios como finalizados. Editar as séries reabre o exercício. **Trocar exercício** altera somente a sessão atual, sem modificar a rotina; o diálogo avisa que as séries do exercício substituído serão removidas. O histórico registra o exercício realizado e a marcação de conclusão.

Na web, os dados pertencem ao navegador e à origem (host e porta). Use a mesma porta para preservar o acesso aos registros durante o desenvolvimento. Limpar os dados do site remove os registros.

## Executar na web

```sh
flutter pub get
flutter run -d chrome --web-port=8080
```

Para Android/iOS, selecione um dispositivo disponível com `flutter devices` e execute `flutter run -d <id>`.

## Verificação

```sh
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
flutter build web --no-pub
```

O Modo de Desenvolvedor do Windows é necessário para links simbólicos de plugins em builds desktop Windows; não é requisito para usar esta aplicação no navegador.
