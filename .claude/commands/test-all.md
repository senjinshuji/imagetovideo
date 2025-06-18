---
description: Run all tests with coverage
---

Run the following commands in order:
1. npm test -- --coverage && echo -e "\a✅ テスト完了！"
2. npm run lint && echo -e "\a✅ リント完了！"
3. npm run type-check && echo -e "\a✅ 型チェック完了！"
4. If all pass, create a success commit && echo -e "\a🎉 全て完了！"