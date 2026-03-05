好的，基于 AMIA 2026 的投稿要求和目前的文献现状，我帮你完整规划论文架构和实验设计。

---

## 一、投稿须知速览

AMIA 2026 Annual Symposium 的 Paper 类型要求 5–10 页（含表、图、参考文献），需包含摘要（125–150 词）、引言、方法、结果、讨论等部分。截稿日期为 2026 年 3 月 10 日 23:59 EDT，时间还算充裕。

---

## 二、建议论文标题

> **Non-Invasive Diabetes Risk Screening Using Routinely Accessible Features: A Machine Learning Approach with NHANES Data and Explainable AI**

关键词突出：non-invasive、routinely accessible（日常可获取）、explainable AI（可解释性是 AMIA 审稿人非常看重的）。

---

## 三、完整论文架构

### Abstract（125–150 词）
按 AMIA 格式写四句式摘要：Background → Methods → Results → Conclusion

---

### 1. Introduction

**要讲清楚三件事：**

**① 问题的重要性**
- 全球糖尿病负担（IDF 数据：5.37 亿患者，约一半未确诊）
- 早筛早治能显著降低并发症风险
- 现有诊断依赖抽血（FPG/HbA1c/OGTT），成本高、依从性差，尤其在资源匮乏地区

**② 现有工作的不足**
- 传统风险评分（FINDRISC、ADA Risk Test）变量少、线性假设、无法捕捉交互效应
- 已有 ML 研究的问题：很多用了侵入性变量（血糖、胰岛素）却声称 non-invasive；特征选择缺乏临床可行性考量；缺少可解释性分析；样本量小或单一数据集
- 引用几篇关键文献：有研究用 NHANES 2007–2018 数据基于生活方式和体测变量预测糖尿病，比较了 LR、SVM、RF、XGBoost、CatBoost 五种模型；另一项研究用 NHANES 做了全变量搜索，建立了心血管和糖尿病检测的集成模型

**③ 你的创新点（Contribution）**
- 严格限制特征为**日常可获取**（自报+简单体测+家用血压计），不含任何血液/尿液检测
- 多周期 NHANES 数据合并，大样本量
- 系统对比多种 ML 模型 + 传统风险评分（FINDRISC/ADA）作为 baseline
- 使用 SHAP 进行可解释性分析，揭示特征重要性和交互效应
- 亚组分析（按年龄/性别/种族），评估公平性

---

### 2. Methods

#### 2.1 Data Source & Study Population

```
数据源：NHANES 1999–2020 pre-pandemic（多周期合并）
纳入标准：≥18 岁非孕成人
排除标准：
  - 已确诊糖尿病（DIQ010==1）→ 如果做"筛查未诊断糖尿病"
  - 或者保留已确诊，做三分类（正常/前期/糖尿病）
  - 缺少 HbA1c 数据者
  - 孕妇（RIDEXPRG==1 或 UCPREG 阳性）
预期样本量：40,000–60,000人
```

画一个 **CONSORT-style 流程图**，展示样本筛选过程（AMIA 审稿人很看重这个）。

#### 2.2 Outcome Definition（Y 标签）

```
基于 HbA1c（GHB 文件）：
  - 正常：HbA1c < 5.7%
  - 糖尿病前期：5.7% ≤ HbA1c < 6.5%
  - 糖尿病：HbA1c ≥ 6.5% 或 自报已确诊(DIQ010==1)

主实验：二分类（正常 vs 糖尿病前期+糖尿病）
辅助实验：三分类（正常 vs 前期 vs 糖尿病）
```

#### 2.3 Feature Engineering（核心亮点）

**明确定义"日常可获取"的标准**——这是你区别于其他论文的关键：

| 获取方式 | 特征（~25个） | 变量 |
|---------|-------------|------|
| **自报（问几句话）** | 年龄、性别、种族、教育、收入、糖尿病家族史、高血压史、高血压用药、高胆固醇史、吸烟状态、饮酒频率、体力活动量、久坐时间、睡眠时长、妊娠糖尿病史(女)、10年前体重 | DEMO + MCQ + BPQ + SMQ + ALQ + PAQ + SLQ + RHQ + WHQ |
| **秤+软尺** | BMI、腰围、体重、身高 | BMX |
| **家用血压计** | 收缩压、舒张压、脉搏 | BPX |
| **衍生变量** | 体重变化率=(当前-10年前)/10年前、腰围/身高比 | 计算 |

#### 2.4 Models

```
(1) 传统 Baseline（复现）：
    - FINDRISC 评分（8变量线性加权）
    - ADA Risk Test（7变量）
    - Logistic Regression

(2) 机器学习模型：
    - Random Forest
    - XGBoost / LightGBM
    - Support Vector Machine (RBF kernel)
    - 多层感知机 (MLP)

(3) 可选：简单集成（Stacking/Voting）
```

#### 2.5 Experimental Setup

```
数据划分：80% 训练 / 20% 测试（按时间划分更好：
  - 训练：1999–2016 周期
  - 测试：2017–2020 周期 → 时间外验证，更有说服力）

交叉验证：训练集上 5-fold stratified CV 用于调参

类别不平衡处理：
  - SMOTE 过采样
  - 或 class_weight='balanced'
  - 或 不处理（报告两种结果）

缺失值处理：
  - Multiple Imputation (MICE) 或 中位数填充
  - 报告缺失率表

超参数调优：
  - RandomizedSearchCV 或 Optuna
```

#### 2.6 Evaluation Metrics

```
主指标：AUROC（AUC）
辅指标：
  - AUPRC（PR曲线下面积，对不平衡数据更敏感）
  - Sensitivity / Specificity（在多个阈值下报告）
  - F1-score
  - 校准曲线（Calibration plot）→ 临床可信度
  - 决策曲线分析（DCA）→ 临床净获益

95% CI：Bootstrap 1000次
统计检验：DeLong test 比较模型间 AUC 差异
```

#### 2.7 Explainability Analysis

```
- SHAP (SHapley Additive exPlanations)：
  - Global feature importance（蜂群图）
  - Partial dependence plots（关键特征的非线性效应）
  - SHAP interaction values（特征交互，如 BMI × 年龄）

- 个案解释：选 2-3 个代表性样本展示 SHAP waterfall plot
```

#### 2.8 Fairness & Subgroup Analysis

```
按以下维度分层报告 AUC：
  - 年龄组：18–39 / 40–59 / ≥60
  - 性别：男 / 女
  - 种族：Non-Hispanic White / Black / Hispanic / Asian
  - BMI：正常 / 超重 / 肥胖

检查模型是否在特定亚群表现差 → 公平性分析
```

---

### 3. Results

建议包含以下 **表和图**：

| 编号 | 内容 | 类型 |
|------|------|------|
| Table 1 | 研究人群基线特征（按糖尿病状态分组） | 表 |
| Table 2 | 各模型性能对比（AUC, Sensitivity, Specificity, F1, AUPRC） | 表 |
| Figure 1 | 样本筛选流程图 | 图 |
| Figure 2 | ROC 曲线对比（所有模型在一张图上） | 图 |
| Figure 3 | SHAP 全局特征重要性蜂群图 | 图（**最有吸引力**） |
| Figure 4 | 校准曲线 | 图 |
| Table 3 | 亚组分析（按性别/种族/年龄的 AUC） | 表 |
| Figure 5 | 决策曲线分析（DCA） | 图（可选） |

---

### 4. Discussion

**要讨论的要点：**

1. **主要发现**：ML 模型（特别是 XGBoost）在纯 non-invasive 特征上的 AUC 比 FINDRISC 高多少？与含侵入性变量的模型差距多大？
2. **关键特征解读**：SHAP 揭示了哪些特征最重要？是否与临床知识一致？有无意外发现？
3. **临床意义**：这个模型可以部署在哪里？（社区药房、健康 App、基层诊所筛查）— 强调降低筛查门槛
4. **公平性**：模型在不同种族/性别中表现是否一致？如果不一致，为什么？
5. **局限性**（必须诚实写）：
   - NHANES 是横截面数据，不能做因果推断
   - HbA1c 单一指标定义糖尿病可能有误分类
   - 自报变量存在回忆偏倚
   - 未使用 NHANES 复杂抽样权重（或如果用了，说明如何用的）
   - 模型未在外部数据集验证
6. **未来工作**：在前瞻性队列验证；整合可穿戴设备数据；部署为 App

---

### 5. Conclusion

3–4 句话总结：用日常可获取的 ~25 个特征 + ML 模型可以达到接近甚至超越传统风险评分的筛查效果，具有低成本、易部署的潜力。

---

## 四、实验执行时间表

| 阶段 | 任务 | 预计耗时 |
|------|------|---------|
| Week 1–2 | 下载 NHANES 数据、合并多周期、清洗 | 2 周 |
| Week 3 | 特征工程、缺失值处理、EDA | 1 周 |
| Week 4–5 | 模型训练、调参、交叉验证 | 2 周 |
| Week 6 | SHAP 分析、亚组分析、公平性 | 1 周 |
| Week 7 | 画图、做表 | 1 周 |
| Week 8–9 | 写论文 | 2 周 |
| Week 10 | 内部审阅、修改、提交 | 1 周 |

---

## 五、让你的论文脱颖而出的关键

1. **严格定义"non-invasive"** — 很多论文混入了血液指标还说自己是 non-invasive，你要明确区分
2. **与经典风险评分做 head-to-head 对比** — 不只是比 ML 之间，要比 FINDRISC/ADA
3. **SHAP 可解释性** — AMIA 审稿人非常看重临床可解释性，不喜欢黑箱
4. **时间外验证** — 训练在旧周期、测试在新周期，比随机拆分更有说服力
5. **公平性分析** — 这是近两年 AMIA 的热点话题，加分项

需要我帮你写数据下载和预处理的代码，或者帮你起草论文的某个章节吗？