import commander
proc otherDoc*(cmd: Commander) =
  genCommand(cmd):
    section("Other File", "Simple implementation from the beyond", "Does some simple stuff")
    flag(short = "t", desc = "This echo's got T if it was supplied"):
      echo "got T"
