import matplotlib.pyplot as plt
import numpy as np

# 数据准备
layers = np.arange(24)
# 0-7: 68.75%, 8-15: 81.25%, 16-23: 68.75%
zero_ratios = [68.75] * 8 + [81.25] * 8 + [68.75] * 8

# 设置全局字体大小，适应论文排版
plt.rcParams.update({'font.size': 12, 'font.family': 'serif'})

# 创建图表
fig, ax = plt.subplots(figsize=(10, 5))

# 为不同阶段设置不同的颜色，突出中层的差异
# 浅色蓝 (Early/Late Stage) 和 深色橙 (Middle Stage)
colors = ['#4C72B0'] * 8 + ['#DD8452'] * 8 + ['#4C72B0'] * 8

# 绘制柱状图
bars = ax.bar(layers, zero_ratios, color=colors, edgecolor='black', alpha=0.85, zorder=3)

# 绘制理论平均值的水平参考线
theoretical_avg = 72.91
empirical_avg = 72.63
ax.axhline(y=theoretical_avg, color='red', linestyle='--', linewidth=2, 
           label=f'Theoretical Avg ({theoretical_avg}%)', zorder=4)

# 坐标轴设置
ax.set_xlabel('Transformer Layer Index', fontweight='bold')
ax.set_ylabel('Zero Ratio (%)', fontweight='bold')
ax.set_title('Theoretical Sparsity Distribution across Layers', fontweight='bold', pad=15)

# 设置X轴刻度为 0 到 23
ax.set_xticks(layers)

# 设置Y轴范围，稍微留白让图形更好看
ax.set_ylim(0, 100)

# 在对应区块的中心上方添加数值文本标签，增强可读性
ax.text(3.5, 68.75 + 2, '68.75%', ha='center', va='bottom', fontsize=11, fontweight='bold', color='#4C72B0')
ax.text(11.5, 81.25 + 2, '81.25%', ha='center', va='bottom', fontsize=11, fontweight='bold', color='#DD8452')
ax.text(19.5, 68.75 + 2, '68.75%', ha='center', va='bottom', fontsize=11, fontweight='bold', color='#4C72B0')

# 添加网格线，仅显示Y轴方向，且置于底层
ax.grid(axis='y', linestyle='--', alpha=0.6, zorder=0)

# 添加图例
ax.legend(loc='lower right', framealpha=0.9)

# 紧凑布局
plt.tight_layout()

# 保存为高质量 PDF 格式，便于直接插入 LaTeX
plt.savefig('layerwise_sparsity_distribution.pdf', format='pdf', dpi=300)

# 显示图表
plt.show()