from collections import namedtuple

M = namedtuple('Mapping', ['pio', 'iol', 'gpio'])


PIN_MAPPINGS = {
	"GPIO1": {
		M('PIO3_00', 'IOL_1A', 5):		'E4',
		M('PIO3_01', 'IOL_1B', 7):		'B2',
		M('PIO3_02', 'IOL_2A', 9):		'F5',
		M('PIO3_03', 'IOL_2B', 11):		'B1',
		M('PIO3_04', 'IOL_3A', 13):		'C1',
		M('PIO3_05', 'IOL_3B', 15):		'C2',
		M('PIO3_06', 'IOL_4A', 17):		'F4',
		M('PIO3_07', 'IOL_4B', 19):		'D2',
		M('PIO3_08', 'IOL_5A', 21):		'G5',
		M('PIO3_09', 'IOL_5B', 23):		'D1',
		M('PIO3_10', 'IOL_6A', 25):		'G4',
		M('PIO3_11', 'IOL_6B', 27):		'E3',
		M('PIO3_12', 'IOL_7A', 29):		'H5',
		M('PIO3_13', 'IOL_7B', 31):		'E2',
		M('PIO3_14', 'IOL_8A', 33):		'G3',
		M('PIO3_15', 'IOL_8B', 34):		'F3',
		M('PIO3_16', 'IOL_9A', 32):		'H3',
		M('PIO3_17', 'IOL_9B', 30):		'F2',
		M('PIO3_18', 'IOL_10A', 28):	'H6',
		M('PIO3_19', 'IOL_10B', 26):	'F1',
		M('PIO3_20', 'IOL_11A', 24):	'H4',
		M('PIO3_21', 'IOL_11B', 22):	'G2',
		M('PIO3_22', 'IOL_12A', 20):	'J4',
		M('PIO3_23', 'IOL_12B', 18):	'H2',
		M('PIO3_24', 'IOL_13A', 16):	'J5',
		M('PIO3_25', 'IOL_13B', 14):	'G1',
		M('PIO3_27', 'IOL_14B', 12):	'H1',
		M('PIO3_28', 'IOL_15A', 10):	'J2'
	}
}

UTIL_PINS = {
	"RXD": "L11",
	"TXD": "T16",
	"LED1": "M12",
	"LED2": "R16",
	"BUT1": "K11",
	"BUT2": "P13"
}


def get_gpio_pin(pin_num: int, gpio: str = "GPIO1") -> str:
	for entry in PIN_MAPPINGS[gpio].keys():
		if entry.gpio == pin_num:
			return [entry, PIN_MAPPINGS[gpio][entry]]


def get_pio_pin(pin_num: int, pio: str = "PIO3", gpio: str = "GPIO1"):
	for entry in PIN_MAPPINGS[gpio].keys():
		entry_pio, pin = entry.pio.split("_")
		if entry_pio == pio and int(pin) == pin_num:
			return [entry, PIN_MAPPINGS[gpio][entry]]
	

def get_pad(pad: str):
	for gpio in PIN_MAPPINGS.values():
		for mappings, item_pad in gpio.items():
			if item_pad == pad:
				return [mappings, item_pad]
			

def print_mapping():
	OUTPUT_MAPPING = {
		"rd_irq":"E4",
		"PH2A1":"B2",
		"PH2A2":"F5",
		"PH1A1":"B1",
		"PH1A2":"C1",
		"CP":"C2",
		"RS":"F4",
		"PH1B":"D2",
		"PHC":"G5",
		"SH": "D1"
	}

	INPUT_MAPPING = {
		"start": "P13",
		"rst_n": "K11",
		"cp_mode":"F2",
		"cpu_irq": "F3",
		"mode": "F1"
	}

	print(f"{'Name':^10} | {'Pad':^10} | {'GPIO1 Pin':^10} |")

	print(f"{' OUTPUTS ':=^40}")
	for signal, pad in OUTPUT_MAPPING.items():
		gpio_pin = get_pad(pad)[0].gpio
		print(f"{signal:<10} | {pad:<10} | {gpio_pin:<10} [{'L' if gpio_pin % 2 else 'R'}]")

	print(f"{' INPUTS ':=^40}")
	for signal, pad in INPUT_MAPPING.items():
		gpio_pin = get_pad(pad)
		if gpio_pin is None:
			gpio_pin = -1
		else:
			gpio_pin = get_pad(pad)[0].gpio
		print(f"{signal:<10} | {pad:<10} | {gpio_pin:<10} [{'L' if gpio_pin % 2 else 'R'}]")

def generate_pcf():
	pins = {
		# Left
		## Phase 1
		"PH1A1": 5,
		"PH1A2": 7,
		"PH1B":  9,
		## Phase 2
		"PH2A1": 11,
		"PH2A2": 13,
		## Phase C
		"PHC": 15,
		## Control Lines
		"CP":	17,
		"RS":	19,
		"SH":	21,
		## Status IO
		"pixel_ready": 	UTIL_PINS["LED1"],
		"init_state":	25,
		"ready":		27,
	}

	inputs = {
		# RIGHT (Inputs)
		"clk":			"J3",
		"rst_n":		UTIL_PINS["BUT1"],
		"read_i":		34,
		"advance":		UTIL_PINS["BUT2"],
		"cp_mode":		32,
		"line_mode":	30
	}

	pcf_string = ""
	for key, value in pins.items():
		if type(value) is str:
			pcf_string += f"set_io\t{key}\t{value}\n"
		else:
			pcf_string += f"set_io\t{key}\t{get_gpio_pin(value)[1]}\n"
	
	for key, value in inputs.items():
		if type(value) is str:
			pcf_string += f"set_io -pullup yes {key}\t{value}\n"
		else:
			pcf_string += f"set_io -pullup yes {key}\t{get_gpio_pin(value)[1]}\n"

	return pcf_string

def write_pcf():
	with open("../filmscanner.pcf", "wt") as pcf_file:
		pcf_file.write(generate_pcf())


if __name__ == "__main__":
	write_pcf()