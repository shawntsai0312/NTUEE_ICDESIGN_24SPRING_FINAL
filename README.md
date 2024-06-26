# IC Design 24Spring Final

##### author: B10901176 蔡弘祥

### Problem [doc](./04_DOC/ICD_FINAL.pdf)

### Before running

```shell
source tool.sh
```
  
### How to Run

```shell
cd 01_RTL
chmod u+x *.sh
./01_run.sh
```

### State transition and I/O

![state](./04_DOC/state.jpg)

### SubModule

1. Need_ask2: check if the next state of `S_CALC` is `S_ASK2`
2. Edge: find the index of the right/top pixel of the current output pixel 
3. Interpolate2
    ![state](./04_DOC/interpolate2.png)

### Python

- convert the rom data and golden data into matrix form
- change parameters on the top of the file

```shell
cd 00_TESTED/python
python toCSV.py
```

```python
# toCSV.py
pChoice = 2     # P2
testData = 3    # 3rd data
```
