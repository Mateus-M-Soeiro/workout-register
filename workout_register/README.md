# Ritmo

Aplicação Flutter para organizar rotinas, registrar séries e acompanhar a evolução.

O botão flutuante **+** cria rotinas. Durante um treino, a marcação de conclusão fica junto ao nome do exercício e **Adicionar exercício ao treino** inclui exercícios somente na sessão atual, com salvamento no rascunho e histórico. A tela de evolução possui abas separadas para gráficos e histórico completo.

A classificação usa a hierarquia em `exerciseCategoryTree`: Peitoral (Clavicular, Esternocostal, Costal), Costas (Dorsal, Trapézio, Romboides, Lombar), Pernas (Quadríceps, Posterior da coxa, Adutor, Abdutor, Panturrilha, Glúteo), Braço (Tríceps, Bíceps, Antebraço) e Abdômen. É possível selecionar múltiplas subcategorias; Abdômen pode ser selecionado diretamente. A opção Geral foi removida. Na primeira abertura desta versão, as classificações dos exercícios já salvos são limpas uma única vez, mantendo exercícios, rotinas e treinos. Novas classificações são preservadas nas próximas aberturas. Filtros de categoria incluem todas as suas subcategorias. As chaves anteriores continuam válidas.

No menu de três pontos no topo de **Minhas rotinas**, abra **Exercícios salvos** para editar nomes e grupos ou excluir exercícios do catálogo. Renomear atualiza as rotinas; o histórico e o treino já iniciado preservam seus nomes originais. Excluir exige confirmação e remove o exercício das novas seleções, preservando rotinas existentes e registros anteriores.

**Abortar treino** fica no topo da tela de treino e no cartão de retomada do menu. Após confirmação, remove o treino em andamento sem criar uma entrada no histórico.

- **Rotinas:** criação e edição em modal, lista de exercícios e exclusão de rotinas.
- **Catálogo de exercícios:** os exercícios ficam salvos para reutilização, mesmo após remover uma rotina. Ao montar a rotina ou substituir um exercício, filtre por categoria principal ou subcategoria. Cada exercício pode ter múltiplos grupos; registros anteriores aparecem como “Sem grupo” e podem ser classificados pelo ícone de ajustes no seletor. Os grupos usam chaves estáveis em `exerciseGroups`, permitindo ampliar a lista no futuro.
- **Treino:** exercícios começam sem séries e podem permanecer assim ao concluir. Séries adicionadas exigem repetições e peso válidos e podem ser removidas. Aceita peso decimal com vírgula ou ponto e 0 kg para exercícios sem carga externa. Exibe as séries da última sessão da mesma rotina como referência e registra data/hora de início e fim.
- **Histórico:** acesso por rotina ou pelo ícone no topo do menu, com início, fim e valores individuais de cada série. Sessões antigas são preservadas, com início indicado como não registrado. O vínculo antigo por nome é recuperado quando há uma única rotina correspondente; registros ambíguos continuam no histórico geral.
- **Evolução:** gráficos diários de repetições ou volume (peso × repetições), períodos de 7/30 dias e histórico com detalhes das séries.

Rotinas, histórico e o treino em andamento são salvos localmente com `shared_preferences`. As alterações no treino são salvas a cada edição e ao entrar em background. Ao reabrir, use **Retomar treino**, mantendo o horário original de início. Voltar ao menu conserva o treino; **Abortar treino** remove o rascunho após confirmação. Ao concluir, o histórico e a remoção do rascunho são gravados juntos.

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
