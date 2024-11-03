-----------------------------------------------------------
--                       _oo0oo_
--                      o8888888o
--                      88" . "88
--                      (| -_- |)
--                      0\  =  /0
--                    ___/`---'\___
--                  .' \\|     |-- '.
--                 / \\|||  :  |||-- \
--                / _||||| -:- |||||- \
--               |   | \\\  -  --/ |   |
--               | \_|  ''\---/''  |_/ |
--               \  .-\__  '-'  ___/-. /
--             ___'. .'  /--.--\  `. .'___
--          ."" '<  `.___\_<|>_/___.' >' "".
--         | | :  `- \`.;`\ _ /`;.`/ - ` : | |
--         \  \ `_.   \_ __\ /__ _/   .-` /  /
--     =====`-.____`.___ \_____/___.-`___.-'=====
--                       `=---='
--
--
--     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--
--               佛祖保佑         永无BUG
--
--
----------------------------------------------------------

--------------------------------------------------
--  定义优先队列类属
--  
--  使用二叉堆算法
--
--  Yao Fei
--------------------------------------------------
with Interfaces; use Interfaces;

generic
   type Key_Type_1 is private;
   type Key_Type_2 is private;
   type Value_Type is private;
   with function ">=" (L, R : Key_Type_1) return Boolean;
   with function ">=" (L, R : Key_Type_2) return Boolean;
   with function Null_Key_1 return Key_Type_1; -- For null key
   with function Null_Key_2 return Key_Type_2;
   with function Null_Value return Value_Type; -- For null value

package Priority_Queue is
   
   Max_Level    : constant := 10;   -- Maximum number of levels in the skip list
   Max_Nodes    : constant := 512;  -- Maximum number of nodes in the skip list
   
   procedure Flush;
   
   procedure Insert(Cmd_Data : in Value_Type; Key1 : in Key_Type_1; Key2 : in Key_Type_2);
   
   function  Top return Value_Type;
   
   function  Get return Value_Type;
   
   function  Depth return Integer;
   
   function  IsEmpty return Boolean;
   
   function  IsFull return Boolean;

end Priority_Queue;

package body Priority_Queue is

   -- Node structure for the skip list
   type Node_Type;
   type Node_Ptr is access Node_Type;

   type Node_Type is record
      Key1   : Key_Type_1;
      Key2   : Key_Type_2;
      Value  : Value_Type;
      Forward : array (0 .. Max_Level - 1) of Node_Ptr;
   end record;

   type SkipList_Type is record
      Header : Node_Type;
      Level  : Integer := 0;
   end record;

   Skip_List : SkipList_Type;

   -- Memory pool for the nodes
   Node_Array : array (1 .. Max_Nodes) of Node_Type;
   Node_Used  : Integer := 0;

   protected Skip_List_Mux is        
      entry Lock;      
      procedure Release;      
   private 
      List_Idle : Boolean := True;
   end Skip_List_Mux;

   protected body Skip_List_Mux is  
      entry Lock when List_Idle is
      begin
         List_Idle := False;
      end Lock;
      
      procedure Release is
      begin
         List_Idle := True;
      end Release;
   end Skip_List_Mux;

   -- Initialize the skip list by flushing all entries
   procedure Flush is
   begin
      Node_Used := 0;
      Skip_List.Level := 0;
      for i in 0 .. Max_Level - 1 loop
         Skip_List.Header.Forward(i) := null;
      end loop;
   end Flush;

   -- Function to generate a random level for node insertion
   function Random_Level return Integer is
      Level : Integer := 0;
   begin
      while (Random mod 2 = 0) and (Level < Max_Level - 1) loop
         Level := Level + 1;
      end loop;
      return Level;
   end Random_Level;

   -- Insert a new element into the skip list
   procedure Insert(Cmd_Data : in Value_Type; Key1 : in Key_Type_1; Key2 : in Key_Type_2) is
      Update : array (0 .. Max_Level - 1) of Node_Ptr;
      X      : Node_Ptr := Skip_List.Header'Access;
      New_Level : Integer;
   begin
      -- Lock the skip list
      Skip_List_Mux.Lock;

      -- Find the position for the new element
      for i in reverse 0 .. Skip_List.Level loop
         while (X.Forward(i) /= null) and (X.Forward(i).Key1 >= Key1) loop
            X := X.Forward(i);
         end loop;
         Update(i) := X;
      end loop;

      -- Get a new level for this node
      New_Level := Random_Level;
      if New_Level > Skip_List.Level then
         for i in Skip_List.Level + 1 .. New_Level loop
            Update(i) := Skip_List.Header'Access;
         end loop;
         Skip_List.Level := New_Level;
      end if;

      -- Allocate a new node
      if Node_Used < Max_Nodes then
         Node_Used := Node_Used + 1;
         X := Node_Array(Node_Used)'Access;
         X.Key1 := Key1;
         X.Key2 := Key2;
         X.Value := Cmd_Data;
         -- Insert the new node at each level
         for i in 0 .. New_Level loop
            X.Forward(i) := Update(i).Forward(i);
            Update(i).Forward(i) := X;
         end loop;
      end if;

      -- Release the lock
      Skip_List_Mux.Release;
   end Insert;

   -- Return the top element (with the highest Key1 value)
   function Top return Value_Type is
      X : Node_Ptr := Skip_List.Header.Forward(0);
   begin
      if IsEmpty then
         return Null_Value;
      else
         return X.Value;
      end if;
   end Top;

   -- Get and remove the top element (with the highest Key1 value)
   function Get return Value_Type is
      Temp : Value_Type;
      X : Node_Ptr := Skip_List.Header.Forward(0);
   begin
      if IsEmpty then
         return Null_Value;
      else
         Temp := X.Value;
         Delete(X.Key1);
         return Temp;
      end if;
   end Get;

   -- Delete an element by the first key
   procedure Delete(Key1 : in Key_Type_1) is
      Update : array (0 .. Max_Level - 1) of Node_Ptr;
      X      : Node_Ptr := Skip_List.Header'Access;
   begin
      -- Lock the skip list
      Skip_List_Mux.Lock;

      -- Find the element to delete
      for i in reverse 0 .. Skip_List.Level loop
         while (X.Forward(i) /= null) and (X.Forward(i).Key1 >= Key1) loop
            X := X.Forward(i);
         end loop;
         Update(i) := X;
      end loop;

      -- If found, update the pointers
      X := X.Forward(0);
      if (X /= null) and (X.Key1 = Key1) then
         for i in 0 .. Skip_List.Level loop
            if Update(i).Forward(i) /= X then
               exit;
            end if;
            Update(i).Forward(i) := X.Forward(i);
         end loop;

         -- Reduce the skip list level if necessary
         while (Skip_List.Level > 0) and (Skip_List.Header.Forward(Skip_List.Level) = null) loop
            Skip_List.Level := Skip_List.Level - 1;
         end loop;
      end if;

      -- Release the lock
      Skip_List_Mux.Release;
   end Delete;

   -- Other utility functions (IsEmpty, IsFull, Depth)
   function IsEmpty return Boolean is
   begin
      return Node_Used = 0;
   end IsEmpty;

   function IsFull return Boolean is
   begin
      return Node_Used = Max_Nodes;
   end IsFull;

   function Depth return Integer is
   begin
      return Node_Used;
   end Depth;

begin
   Flush;
end Priority_Queue;

