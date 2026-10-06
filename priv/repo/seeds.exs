# Catalog categories only. The market starts with no shops, buyers, or listings.
#
#     mix run priv/repo/seeds.exs

require Ash.Query

taxonomy = [
  {"Radio", "radio",
   [
     {"HF radio", "radio-hf"},
     {"VHF radio", "radio-vhf"},
     {"UHF radio", "radio-uhf"},
     {"CB radio", "radio-cb"},
     {"FRS and GMRS", "radio-frs"},
     {"Amateur handheld", "radio-ht"},
     {"Amateur mobile", "radio-mobile"},
     {"Software-defined radio", "radio-sdr"},
     {"Radio modules", "radio-modules"},
     {"Antennas", "radio-antennas"},
     {"RF adapters", "radio-adapters"},
     {"RF filters", "radio-filters"},
     {"RF amplifiers", "radio-amps"},
     {"Coax and feed line", "radio-coax"}
   ]},
  {"MCUs", "mcu",
   [
     {"AVR", "mcu-avr"},
     {"ARM Cortex-M", "mcu-arm"},
     {"ESP32 and ESP8266", "mcu-esp"},
     {"RP2040", "mcu-rp2040"},
     {"PIC", "mcu-pic"},
     {"STM32", "mcu-stm32"},
     {"RISC-V", "mcu-riscv"},
     {"8051", "mcu-8051"}
   ]},
  {"Boards", "boards",
   [
     {"Development boards", "boards-dev"},
     {"Single-board computers", "boards-sbc"},
     {"Breakout boards", "boards-breakout"},
     {"Arduino-compatible", "boards-arduino"},
     {"Raspberry Pi HATs", "boards-hat"},
     {"FPGA boards", "boards-fpga"},
     {"Carrier boards", "boards-carrier"},
     {"Evaluation kits", "boards-eval"}
   ]},
  {"Sensors", "sensors",
   [
     {"Temperature", "sensors-temperature"},
     {"Humidity", "sensors-humidity"},
     {"Pressure", "sensors-pressure"},
     {"Motion and IMU", "sensors-imu"},
     {"GPS and GNSS", "sensors-gps"},
     {"Light", "sensors-light"},
     {"Proximity", "sensors-proximity"},
     {"Current sense", "sensors-current"},
     {"Voltage sense", "sensors-voltage"},
     {"Gas and air quality", "sensors-gas"},
     {"Microphones", "sensors-mic"},
     {"Camera modules", "sensors-camera"},
     {"Hall effect", "sensors-hall"},
     {"Strain and load", "sensors-load"}
   ]},
  {"Power", "power",
   [
     {"Linear regulators", "power-linear"},
     {"Switching regulators", "power-switching"},
     {"Buck modules", "power-buck"},
     {"Boost modules", "power-boost"},
     {"Battery chargers", "power-chargers"},
     {"Battery management", "power-bms"},
     {"Batteries", "power-batteries"},
     {"Bench supplies", "power-supplies"},
     {"Isolated DC-DC", "power-isolated"},
     {"USB power", "power-usb"},
     {"Supercapacitors", "power-supercap"},
     {"Fuses and protection", "power-protection"}
   ]},
  {"Connectors", "connectors",
   [
     {"Pin headers", "connectors-headers"},
     {"USB connectors", "connectors-usb"},
     {"Barrel jacks", "connectors-barrel"},
     {"JST", "connectors-jst"},
     {"Terminal blocks", "connectors-terminal"},
     {"Board-to-board", "connectors-btb"},
     {"Card edge", "connectors-edge"},
     {"Audio jacks", "connectors-audio"},
     {"RF connectors", "connectors-rf"},
     {"Wire-to-board", "connectors-wtb"}
   ]},
  {"Passives", "passives",
   [
     {"Resistors", "passives-resistors"},
     {"Capacitors", "passives-capacitors"},
     {"Inductors", "passives-inductors"},
     {"Ferrites", "passives-ferrites"},
     {"Crystals and oscillators", "passives-crystals"},
     {"Potentiometers", "passives-pots"},
     {"Transformers", "passives-transformers"},
     {"Resistor networks", "passives-networks"}
   ]},
  {"Semiconductors", "semiconductors",
   [
     {"Diodes", "semi-diodes"},
     {"Transistors", "semi-transistors"},
     {"MOSFETs", "semi-mosfets"},
     {"Thyristors", "semi-thyristors"},
     {"Optocouplers", "semi-opto"},
     {"Logic ICs", "semi-logic"},
     {"Op-amps", "semi-opamps"},
     {"ADC and DAC", "semi-converters"},
     {"Memory ICs", "semi-memory"},
     {"Gate drivers", "semi-drivers"},
     {"Voltage references", "semi-references"},
     {"Analog switches", "semi-switches"}
   ]},
  {"Electromechanical", "electromechanical",
   [
     {"Switches", "electro-switches"},
     {"Relays", "electro-relays"},
     {"Buttons", "electro-buttons"},
     {"Encoders", "electro-encoders"},
     {"Motors", "electro-motors"},
     {"Servos", "electro-servos"},
     {"Solenoids", "electro-solenoids"},
     {"Fans", "electro-fans"},
     {"Speakers", "electro-speakers"},
     {"Buzzers", "electro-buzzers"}
   ]},
  {"Cable and wire", "cable",
   [
     {"Hookup wire", "cable-hookup"},
     {"Ribbon cable", "cable-ribbon"},
     {"USB cables", "cable-usb"},
     {"Jumper wires", "cable-jumper"},
     {"Heat shrink", "cable-heatshrink"},
     {"Sleeving", "cable-sleeving"},
     {"Coax jumpers", "cable-coax"},
     {"Ethernet cables", "cable-ethernet"}
   ]},
  {"Prototyping", "prototyping",
   [
     {"Breadboards", "proto-breadboard"},
     {"Perfboard", "proto-perfboard"},
     {"Bare PCBs", "proto-pcb"},
     {"Solder", "proto-solder"},
     {"Flux", "proto-flux"},
     {"Stencils", "proto-stencils"},
     {"Sockets", "proto-sockets"},
     {"Test clips", "proto-clips"}
   ]},
  {"Test equipment", "test-equipment",
   [
     {"Multimeters", "test-dmm"},
     {"Oscilloscopes", "test-scope"},
     {"Logic analyzers", "test-logic"},
     {"Signal generators", "test-siggen"},
     {"Electronic loads", "test-load"},
     {"LCR meters", "test-lcr"},
     {"Probes", "test-probes"},
     {"Calibrators", "test-cal"}
   ]},
  {"Networking", "networking",
   [
     {"Ethernet modules", "net-ethernet"},
     {"Wi-Fi modules", "net-wifi"},
     {"Bluetooth and BLE", "net-ble"},
     {"LoRa", "net-lora"},
     {"Cellular modules", "net-cellular"},
     {"CAN", "net-can"},
     {"RS-485", "net-rs485"},
     {"NFC and RFID", "net-nfc"}
   ]},
  {"Audio", "audio",
   [
     {"Audio amplifiers", "audio-amps"},
     {"Audio codecs", "audio-codecs"},
     {"Audio DACs", "audio-dac"},
     {"MIDI", "audio-midi"},
     {"Mixers", "audio-mixers"},
     {"Preamps", "audio-preamps"},
     {"Speaker drivers", "audio-speakers"},
     {"Microphones", "audio-mics"}
   ]},
  {"Displays", "displays",
   [
     {"Character LCD", "displays-character"},
     {"Graphic LCD", "displays-graphic"},
     {"OLED", "displays-oled"},
     {"TFT", "displays-tft"},
     {"E-paper", "displays-epaper"},
     {"Seven-segment", "displays-segment"},
     {"LED matrices", "displays-matrix"},
     {"Touch panels", "displays-touch"}
   ]},
  {"Lighting", "lighting",
   [
     {"Indicator LEDs", "lighting-leds"},
     {"LED strips", "lighting-strips"},
     {"LED drivers", "lighting-drivers"},
     {"Lasers", "lighting-lasers"},
     {"EL wire", "lighting-el"},
     {"Lamps", "lighting-lamps"}
   ]},
  {"Enclosures", "enclosures",
   [
     {"Project boxes", "enclosures-boxes"},
     {"Standoffs", "enclosures-standoffs"},
     {"Fasteners", "enclosures-fasteners"},
     {"Heatsinks", "enclosures-heatsinks"},
     {"Gaskets", "enclosures-gaskets"},
     {"Panels and faceplates", "enclosures-panels"}
   ]},
  {"Custom", "custom",
   [
     {"Custom PCB", "custom-pcb"},
     {"Custom cable", "custom-cable"},
     {"Custom enclosure", "custom-enclosure"},
     {"Repair and rework", "custom-repair"}
   ]}
]

ensure = fn name, slug, parent_id ->
  existing =
    OdinMarket.Catalog.Category
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.read_one!(authorize?: false)

  if existing do
    existing
  else
    {:ok, created} =
      Ash.create(
        OdinMarket.Catalog.Category,
        %{name: name, slug: slug, parent_id: parent_id},
        action: :create,
        authorize?: false
      )

    IO.puts("Added category #{name}.")
    created
  end
end

Enum.each(taxonomy, fn {name, slug, children} ->
  parent = ensure.(name, slug, nil)

  Enum.each(children, fn {child_name, child_slug} ->
    ensure.(child_name, child_slug, parent.id)
  end)
end)
