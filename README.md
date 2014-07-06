# JBStackedBarChartView

This fork has for solely purpose to implement a stackedBarGraph. 
Everything is purely inspired from <a href="https://github.com/Jawbone/JBChartView">JBChartView by Jawbone</a>, refer to their repo for principal doc.

My result is like in the following picture: 
<br/>
<p align="center">	
	<img src="https://raw.github.com/philippeauriach/JBChartView/master/Screenshots/stackedBarChart.png">
</p>

See the code for a fully demo, but basically you just have to use the class <code>JBStackedBarChartView</code> instead of <code>JBBarChartView</code> and implement those two new methods: 

	- (CGFloat)barChartView:(JBStackedBarChartView *)barChartView heightForBarViewAtAtIndex:(NSUInteger)index forDataIndexInsideBar:(NSUInteger)dataIndex;

and

	- (NSUInteger)numberOfStackedBarsInBarChartView:(JBStackedBarChartView *)barChartView forIndex:(NSUInteger)index;