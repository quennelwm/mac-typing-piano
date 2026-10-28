# A-002T 处理配方

固定VCSL commit c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e，Steinway B NoSus Close vl2 rr1。单层32根，MIDI33–96，每音至多±1半音。使用已授权原始下载清单，不读取A-001C低电平引擎试听。

保留全部原始立体声文件。复用A-001 read_wav/resample/write_wav/pitch_evidence纯函数，不调用其写旧目录的build入口。原PCM24/44.1kHz/stereo，阈值max(峰值×.001,2LSB)，第一越阈前保留2ms，最长8s，64tap Hann窗sinc转换48kHz，末80ms余弦平方淡出。全32根沿用A-001 Steinway公共增益，不逐音归一化、不校音、不加混响/EQ/压缩。写stereo24中间件后(L+R)/2降混，再最近偶数舍入为mono16，无随机抖动；这些有损选择仅供试用。

SF2复用A-001B二进制结构，改为32个不重叠音区。program0/MSB121/LSB0；preset/bank0/0。每根46个零guard；无循环；root/pitch correction按记录分别为MIDI根音/0。releaseVolEnv为round(1200log2(.4))=−1586 timecents，实际编码约400.073ms；并非硬件可听尾音时长保证。其余包络/默认modulator保持原试载路线，无额外reverb/chorus。

复现：从项目根目录依次运行 `python3 Design/Audio/trial/A-002T/scripts/fetch_sources.py`（已缓存则校验不重复下载）、`OPENBLAS_NUM_THREADS=1 python3 Design/Audio/trial/A-002T/scripts/build_trial.py`、`python3 Design/Audio/trial/A-002T/scripts/verify_trial.py`。仅使用既有Python/NumPy/requests/jsonschema；无全局安装。源码、原输入、公共增益、每根处理/误差/hash在同包JSON及docs/evidence/A-002T。运行时库只需bank和许可/参数/manifest，不必把原始及中间WAV复制进App。

此包candidate，工程试用默认可替换，非最终听感冻结。正式音量/全音实载/多音/快打/panic由代码角色验收；输出应使用Float32或合理电平，禁止把极低电平PCM16放大48dB的旧试听当新音质证据。
