import numpy as np
np.seterr(over='ignore')


class CPU:
  
    regs = np.array([0b0,0b0,0b0,0b0,0b0,0b0,0b0,0b0], dtype=np.uint8)
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

        
        if(instruction & 0b1100_0000 == 0b1000_0000):
            match (instruction >> 4) & 0b11:
                case 0b00:
                    self.accs[acc] = regval
                
                case 0b01:
                    self.regs[reg] = accval
                
                case 0b10:
                    self.accs[acc] = self.ram.read(False,accval)
                
                case 0b11:
                    self.ram.write(regval,accval)
                
                case _:
                    raise ValueError()
                

        elif(opcode == 0b0100):
            if(self.flags == [False, False] and instruction & 0b1000): self.flags = [True,True]
            elif(self.flags == [False, True] and instruction & 0b0100) : self.flags = [True, True]
            elif(self.flags == [True, False] and instruction & 0b0010) : self.flags = [True, True]
            elif(self.flags == [True,True] and instruction & 0b0001) : self.flags = [True, True]
        
        elif(opcode == 0b0101):
            a : np.uint8 = self.accs[0]
            b : np.uint8 = self.accs[1]

            sa : np.int8 = a.astype(np.int8)
            sb : np.int8 = b.astype(np.int8)

            # TODO: find use for the free mistery bit

            # signed
            if(sa - sb > 0 and instruction &  0b0100): self.flags[0] = True
            elif(sa == sb and instruction & 0b0010): self.flags[0] = True
            elif(sa - sb < 0 and instruction & 0b0001): self.flags[0] = True

            #unsigned
            if(a - b > 0 and instruction &  0b0100): self.flags[1] = True
            elif(a == b and instruction & 0b0010): self.flags[1] = True
            elif(a - b < 0 and instruction & 0b0001): self.flags[1] = True

        
        elif(opcode == 0b0110):
            if(self.flags[0]):
                if(0b1000 & instruction):
                    self.ram.write(np.uint8(0xFF),self.regs[7])
                
                self.ip = regval
                return
            
        else:
            # patching in add imediate instruction
            if(instruction & 0b1110_0000 == 0b0000_0000):
                opcode = 0b0010
                regval = (instruction & 0b0111) | ((instruction & 0b0001_0000) >> 1)

            self.accs[acc], self.flags = self.alu.compute(opcode,accval, regval)

        self.ip += 1
        return

        
            


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
