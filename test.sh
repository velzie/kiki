. ./json.sh

json\
  .a 1\
  .b 2\
  !object 2\
    .a 1\
    @b 2\
      . 1\
      ! 2\
        .b 1\
        .a 2\
  .c 1


json\
  .type "i loadasd"
