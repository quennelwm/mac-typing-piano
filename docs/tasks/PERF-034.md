# PERF-034：常驻CPU/内存调查
用户明确同步要求低CPU低内存。主授权只读当前App的PID级top/ps/sample和源码诊断，可写docs/evidence/PM-034/performance-baseline；不改变App模式/系统/权限，不记录真实按键内容。观察状态与受控空闲区分，记录机器、时间、PID版本、CPU区间和RSS。提出可复现热点建议后由C034唯一改Code；前后用同口径比较，不能以累计ps CPU或离屏基准代替真实常驻表现。
