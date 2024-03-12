from decimal import Decimal, Context, localcontext
from math import ceil
t1 = 120
t2, t4 = (0, 0)
t5 = 1000
t6 = 500
t7 = 10
t8, t9 = (0, 0)
t10, t11 = (0, 0)
t12 = 8
t13 = 0
t14 = 8
t15 = 0
t16, t17 = (0, 0)
t18 = 8
t19 = 8

RS_CP_RISE_spacing = ("Delay between RS rise and CP rise", t10 + t13)
RS_CP_FALL_spacing = ("Delay between RS fall and CP fall", t14 + t17)
CP_FALL_to_PHC_fall = ("Delay between fall of CP and Phase C", t15)




def optimal_counter_limit(count: float, delay_min: float, delay_max: float):
	with localcontext() as ctx:
		ctx.prec = 3
		results = []
		for freq in range(int(5E6), int(36E6), int(1E6)):
			freq_period = 1 / freq
			count_time = freq_period * count
			append_val = [
				freq, freq_period, 
				count, count_time * 1E9, 
				count_time >= delay_min, count_time <= delay_max
			]
			append_val = [Decimal(x).normalize().to_eng_string() for x in append_val]
			results.append(append_val)

		print(f"{'RESULTS':=^100}")
		print(f"{'Frequency':^20}|{'Period':^10}|{'Counter Max':^15}|{'Delay Time (ns)':^15}|{'>= min':^8}|{'<= max':^8}")
		print(f"{'':-^20}|{'':-^10}|{'':-^15}|{'':-^15}|{'':-^8}|{'':-^8}")
		for entry in results:
			print(f"{entry[0]:^20}|{entry[1]:^10}|{entry[2]:^15}|{entry[3]:^15}|{entry[4]:^8}|{entry[5]:^8}")



def optimal_counter_limit2(period: float, delay_min: float, delay_max: float):
	with localcontext() as ctx:
		ctx.prec = 3
		results = []
		for freq in range(int(5E6), int(36E6), int(1E6)):
			freq_period = 1 / freq
			count = period / freq_period
			count_time = freq_period * count
			append_val = [
				freq, freq_period, 
				count, count_time * 1E9, 
				count_time >= delay_min, count_time <= delay_max
			]
			append_val = [Decimal(x).normalize().to_eng_string() for x in append_val]
			results.append(append_val)

		print(f"{'RESULTS':=^100}")
		print(f"{'Frequency':^20}|{'Period':^10}|{'Counter Max':^15}|{'Delay Time (ns)':^15}|{'>= min':^8}|{'<= max':^8}")
		print(f"{'':-^20}|{'':-^10}|{'':-^15}|{'':-^15}|{'':-^8}|{'':-^8}")
		for entry in results:
			print(f"{entry[0]:^20}|{entry[1]:^10}|{entry[2]:^15}|{entry[3]:^15}|{entry[4]:^8}|{entry[5]:^8}")