<h1 align="center">CPU-Cache-Mem on Verilog</h1>
<h4 align="center">Homework on CPU-Cache-Mem modeling in Verilog for the Computer Architecture course at ITMO University</h4>

- [Report (in Russian)](https://github.com/npanuhin/ITMO-Verilog/blob/master/report/report.pdf?raw=true)

---

### Полезные ссылки:

**Общее про кеш на Verilog:**
- Habr: [Имплементация кэша на Verilog](https://habr.com/ru/post/461611/)
- [Simple direct-mapped cache simulation on FPGA](https://github.com/psnjk/SimpleCache)
- YouTube: [Как работает Кэш](https://youtu.be/7n_8cOBpQrg)

**Разное:**
- Как работать с `inout`: https://www.fpga4student.com/2017/05/how-to-write-verilog-testbench-for.html


#### Рассчёт констант
```py
CACHE_SIZE = CACHE_LINE_SIZE × CACHE_LINE_COUNT
CACHE_SETS_COUNT = CACHE_LINE_COUNT / CACHE_WAY
CACHE_SET_SIZE = log2(CACHE_SETS_COUNT)
CACHE_OFFSET_SIZE = log2(CACHE_LINE_SIZE)
CACHE_ADDR_SIZE = log2(MEM_SIZE) = CACHE_TAG_SIZE + CACHE_SET_SIZE + CACHE_OFFSET_SIZE
```

#### Размеры шин
```py
ADDR1_BUS_SIZE = max(CACHE_TAG_SIZE + CACHE_SET_SIZE, CACHE_OFFSET_SIZE)
ADDR2_BUS_SIZE = CACHE_TAG_SIZE + CACHE_SET_SIZE
CTR1_BUS_SIZE = 3 | потому что коды команд 0..7
CTR2_BUS_SIZE = 2 | потому что коды команд 0..3
```

#### Little endian

Пусть мы должны передать 16 бит (2 байта):
```py
00110101 10011110
```

Тогда нужно развернуть только байты, а порядок бит оставить:
```py
10011110 00110101
```

#### Кусок из конспектов про ассоциативность
> Итак, мы имеем размер кэш-линии 64 Б, размер L1 — 32кБ, то есть в L1 есть 512 линий. Как понять, что там где хранится? В каждой линии помимо 64 байта данных есть теги адреса. Чтобы проверить, если в кэше данные, нам нужно посмотреть все 512 линий, не говоря уже о том, чтобы данные как-то читать. И в L2 и L3 всё только хуже. Что-то с этим надо делать. Итак, у нас есть 32 бита адреса. Младшие 6 бит, как мы знаем, можно игнорировать, пока ищем кэш-линию. После этого мы берём следущие 9 бит, как номер кэш-линии. Тут мы получим ассоциативность-1, когда позиция в кэше считается, а не ищется. И нам нужно только сравнить адрес кэш-линии с тем, что мы имеем. А имеем мы прямую адресацию. Плюс этого — скорость. Минус этого — мы не можем сохранить в кэше две переменные, у которых эти самые 9 бит адреса совпадают. Поэтому между ассоциативностью-1 (тем, что му уже обсудили) и ассоциативностью-∞ (где мы просто ищем данные в кэше последовательно) берут что-то среднее. Например, ассоциативность-4 — когда у нас кэш-линии группируются блоками по 4, из адреса берутся 7 бит, а не 9, чтобы искать блок, а из 4 линий блока мы честно ищем нужную (если она есть). Тогда мы всегда можем сохранить в кэше 4 переменные, как бы плохо они не были расположены. Какие реальные ассоциативности используются? Например, в L1 и L2 — 8, а L3 – 16. Ассоциативность, кстати, не обязана увеличиваться, возможна ситуация 8/4/16. В L3 ассоциативность может быть вообще не степенью двойки, если у нас размер L3 — не степень двойки.
