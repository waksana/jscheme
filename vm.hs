import Text.Parsec

data Expression = Dest String
                | Number Integer
                | Bool Bool
                | Fetch String
                | Eq Expression Expression
                | Sub Expression Expression
                | Add Expression Expression
                | Mul Expression Expression
                | Div Expression Expression
                | Mod Expression Expression
                deriving (Show)

data Instruction = Label String
                 | Assign String Expression
                 | Branch Expression Expression
                 | Save String
                 | Restore String
                 | Goto Expression
                 deriving (Show)

matchWord :: String -> Parsec String () String
matchWord = foldr (\ x -> (<*>) ((:) <$> char x)) (return [])

parenthesis:: Parsec String () a -> Parsec String () a
parenthesis p = char '(' *> spaces *> p <* spaces <* char ')'

destExpression :: Parsec String () Expression
destExpression = Dest <$> many1 letter

numberExpression :: Parsec String () Expression
numberExpression = Number . read <$> many1 digit

boolExpression :: Parsec String () Expression
boolExpression = Bool . read <$> (matchWord "True" <|> matchWord "False")

fetchExpression :: Parsec String () Expression
fetchExpression = Fetch <$> (matchWord "fetch" >> many1 space *> many1 letter)

eqOperator :: Parsec String () (Expression -> Expression -> Expression)
eqOperator = char '=' >> return Eq

addOperator :: Parsec String () (Expression -> Expression -> Expression)
addOperator = char '+' >> return Add

subOperator :: Parsec String () (Expression -> Expression -> Expression)
subOperator = char '-' >> return Sub

mulOperator :: Parsec String () (Expression -> Expression -> Expression)
mulOperator = char '*' >> return Mul

divOperator :: Parsec String () (Expression -> Expression -> Expression)
divOperator = char '/' >> return Div

modOperator :: Parsec String () (Expression -> Expression -> Expression)
modOperator = char '%' >> return Mod

operator = eqOperator <|> addOperator <|> subOperator <|> mulOperator <|> divOperator <|> modOperator

operatorExpression :: Parsec String () Expression
operatorExpression = do
    op <- operator
    many1 space
    left <- expression
    many1 space
    op left <$> expression

expression :: Parsec String () Expression
expression = numberExpression <|> boolExpression <|> destExpression <|> parenthesis (fetchExpression <|> operatorExpression)

labelInstruction :: Parsec String () Instruction
labelInstruction = Label <$> many1 letter

assignInstruction = do
    matchWord "assign"
    many1 space
    reg <- many1 letter
    many1 space
    Assign reg <$> expression

branchInstruction = do
    matchWord "branch"
    many1 space
    exp <- expression
    many1 space 
    Branch exp <$> (parenthesis fetchExpression <|> destExpression)

stackInstruction = do
    op <- (matchWord "save" >> return Save) <|> (matchWord "restore" >> return Restore)
    many1 space 
    op <$> many1 letter

gotoInstruction = do
    matchWord "goto"
    many1 space 
    Goto <$> (parenthesis fetchExpression <|> destExpression)

instruction = parenthesis (assignInstruction <|> branchInstruction <|> stackInstruction <|> gotoInstruction) <|> labelInstruction

instructions = parenthesis (instruction `sepEndBy` many1 space)

omit name [] = []
omit name ((key, value):xs)
    | name == key = xs
    | otherwise = (key, value):omit name xs
setRegister table name value = (name, value):omit name table

getRegister [] name = error "Register: " ++ name ++ " is not set"
getRegister ((key, value):xs) name
    | name == key = value
    | otherwise = getRegister xs name

eval [] registers totalInstruction = registers
eval ins registers totalInstruction = eval next newRegisters totalInstruction
    where
        (next, newRegisters) = runInstruction ins registers totalInstruction

runInstruction ((Label l):xs) registers _ = (xs, registers)
runInstruction ((Assign registerName exp):xs) registers _ = 
    (xs, setRegister registers registerName (evalExp exp registers))
runInstruction ((Branch exp dest):xs) registers totalInstruction
    | evalExp exp == Bool True = (findNext totalInstruction (evalExp dest), registers)
    | otherwise = (xs, registers)