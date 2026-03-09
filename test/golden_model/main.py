import numpy as np
np.seterr(over='ignore')


class CPU:
  
    regs = np.array([0,0,0,0,0,0,0,0], dtype=np.uint8)
    accs = regs[0:1]
    ip : np.uint8 = np.uint8(0)
    flags : list[bool] = [False, False]

    alu : 'ALU'
    ram : 'RAM'

    def __init__(self, alu : 'ALU', memory : 'RAM'):
        self.alu = alu
        self.ram = memory
        print(self.regs)
        pass

    def step(self):
        instruction = self.ram.read(True,self.ip)

        opcode = (instruction >> 4) & 0xF

        acc : int = int(instruction & 0b0000_1000 != 0b0000_0000)
        reg : int = int(instruction & 0b0000_0111)

        accval : np.uint8 = self.accs[acc]
        regval : np.uint8 = self.regs[reg]

        # patching in add imediate instruction
        if(instruction & 0b1110_0000 == 0b000):
            opcode = 0b0010
            regval = (instruction & 0b0111) | ((instruction & 0b0001_0000) >> 1)

        
            


class ALU:

    def compute(self, opcode, acc, operand):
            

            #print(opcode)
            #opcode = (opcode >> 4) & 0xF
            #print(opcode)

            out = np.uint8(0)
            flags = [False,False]

            match opcode:
                case 0b0010:
                    out = np.uint8(acc + operand)
                    flags[0] = ((~(acc ^ operand) & (acc ^ out)) & 0x80) != 0 # magic
                    flags[1] = out < acc
                case 0b0011:  # subtraction
                    out = np.uint8(acc - operand)
                    flags[0] = ((acc ^ operand) & (acc ^ out) & 0x80) != 0
                    flags[1] = acc < operand
                case 0b0111 : 
                    out = acc ^ operand
                    flags[0] = out == 0b0
                    flags[1] = bin(out).count("1") % 2 == 0
                case 0b1100 : 
                    out = acc & operand
                    flags[0] = out == 0b0
                    flags[1] = bin(out).count("1") % 2 == 0
                case 0b1101 : 
                    out = acc | operand
                    flags[0] = out == 0b0
                    flags[1] = bin(out).count("1") % 2 == 0
                case 0b1110 :
                    out = acc << operand
                    flags[0] = out == 0b0
                    flags[1] = (0b1000_0000 & out) == 0b1000_0000
                case 0b1111 :
                    out = acc >> operand
                    flags[0] = out == 0b0
                    flags[1] = (0b1000_0000 & out) == 0b1000_0000


            return out, flags


class RAM:

    ipage = 0
    dpage = 1

    pages =  np.empty((256, 256), dtype=np.uint8)

    def __init__(self) -> None:
        # TODO: parametrize this
        pass

    def read(self, instr : bool, address : np.uint8):
        # TODO: add some way to read page number
        return self.pages[self.ipage,address] if instr else self.pages[self.dpage,address]
    
    def write(self, address : np.uint8, value : np.uint8):
        # TODO: allow changing page num via MMreg
        self.pages[self.dpage,address] = value


    



c = CPU(ALU(),RAM())
